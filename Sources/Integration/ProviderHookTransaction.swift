import Darwin
import Foundation
import EventBridge

public enum ProviderSetupOperation: String, Codable, Sendable {
    case connect, remove
}

public enum ProviderSetupChange: Equatable, Sendable {
    case installed, removed, unchanged
}

public enum ProviderSetupScope: Equatable, Sendable {
    case lifecycle, claudeQuota
}

public struct ProviderSetupContext: Sendable {
    public let agent: Agent
    public let scope: ProviderSetupScope
    public let configurationDirectory: URL
    public let ownershipDirectory: URL
    public let helperURL: URL
    public let executableURL: URL?

    public init(configurationDirectory: URL, ownershipDirectory: URL, helperURL: URL, executableURL: URL?, agent: Agent = .codex, scope: ProviderSetupScope = .lifecycle) {
        self.scope = scope
        self.agent = agent
        self.configurationDirectory = configurationDirectory
        self.ownershipDirectory = ownershipDirectory
        self.helperURL = helperURL
        self.executableURL = executableURL
    }
}

private struct HookJournal: Codable {
    let version: Int
    let operation: ProviderSetupOperation
    let transactionID: UUID
    let target: HookSetupTarget
    let previousConfiguration: String?
    let candidateConfiguration: String
    let previousOwnership: Data?
    let previousOwnershipDigest: String?
    let nextOwnership: Data?
    let nextOwnershipDigest: String?
    let temporaryName: String
}

/// One transaction implementation, with provider identity fixed for its complete recovery lifetime.
struct ProviderHookTransaction {
    let agent: Agent
    let scope: ProviderSetupScope
    private var ownershipName: String { scope == .lifecycle ? "ownership-v1.json" : "quota-ownership-v1.json" }
    private var journalName: String { scope == .lifecycle ? "pending-v1.json" : "quota-pending-v1.json" }
    private var configurationName: String { ProviderHookPolicy.configurationName(agent) }

    init(agent: Agent, scope: ProviderSetupScope = .lifecycle) {
        self.agent = agent
        self.scope = scope
    }

    func run(_ operation: ProviderSetupOperation, context: ProviderSetupContext,
             support: HookSetupSupport) throws -> ProviderSetupChange {
        try Task.checkCancellation()
        guard context.agent == agent, context.scope == scope, scope == .lifecycle || agent == .claude else { throw ProviderSetupFailure.ownershipConflict }
        if operation == .remove, !(try HookFileDirectory.exists(context.configurationDirectory)) {
            if try HookFileDirectory.exists(context.ownershipDirectory) {
                let records = try HookFileDirectory(context.ownershipDirectory, privateDirectory: true)
                guard try records.read(ownershipName, privateFile: true).data == nil,
                      try records.read(journalName, privateFile: true).data == nil else { throw ProviderSetupFailure.ownershipConflict }
            }
            return .unchanged
        }
        let configuration = try HookFileDirectory(context.configurationDirectory, create: operation == .connect)
        // Remove without an owned record requires no new directories or lock files.
        if operation == .remove, !(try HookFileDirectory.exists(context.ownershipDirectory)) {
            let current = try configuration.read(configurationName)
            let target = target(configuration, helper: context.helperURL.path)
            guard case .unchanged = remove(configuration: current.data, ownership: nil, target: target) else {
                throw ProviderSetupFailure.ownershipConflict
            }
            return .unchanged
        }
        let records = try HookFileDirectory(context.ownershipDirectory, create: operation == .connect, privateDirectory: true)
        let lock = try records.lock()
        defer {
            _ = flock(lock, LOCK_UN)
            close(lock)
        }
        if agent == .claude {
            let otherScope: ProviderSetupScope = scope == .lifecycle ? .claudeQuota : .lifecycle
            try ProviderHookTransaction(agent: agent, scope: otherScope).recover(configuration: configuration, records: records)
        }
        try recover(configuration: configuration, records: records)
        try Task.checkCancellation()
        let previous = try configuration.read(configurationName)
        let previousOwner = try records.read(ownershipName, privateFile: true)
        let setupTarget: HookSetupTarget
        let plan: HookSetupPlan
        if operation == .connect {
            try Self.validateHelper(context.helperURL)
            setupTarget = target(configuration, helper: context.helperURL.path)
            let installationID: UUID
            if let owner = previousOwner.data {
                installationID = try validateOwner(owner, target: setupTarget)
            } else {
                installationID = UUID()
            }
            plan = makePlan(HookSetupInput(agent: agent, configuration: previous.data,
                ownership: previousOwner.data, target: setupTarget, support: support, installationID: installationID))
        } else {
            if let bytes = previousOwner.data {
                _ = try HookConfigurationJSON(data: bytes)
                let owner = try JSONDecoder().decode(HookOwnershipHeader.self, from: bytes)
                setupTarget = target(configuration, helper: owner.target.helperPath)
            } else {
                setupTarget = target(configuration, helper: context.helperURL.path)
            }
            plan = remove(configuration: previous.data, ownership: previousOwner.data, target: setupTarget)
        }
        let candidate: Data
        let nextOwnership: Data?
        switch plan {
        case .unchanged:
            return .unchanged
        case .update(let hooks, let owner):
            candidate = hooks
            nextOwnership = operation == .remove ? nil : owner
        case .conflict:
            throw ProviderSetupFailure.ownershipConflict
        case .unavailable(let failure):
            switch failure {
            case .unverifiedVersion, .unsupportedVersion: throw ProviderSetupFailure.unqualifiedVersion
            case .hooksDisabled: throw ProviderSetupFailure.hooksDisabled
            case .helperUnavailable: throw ProviderSetupFailure.helperUnavailable
            case .unsafeTarget: throw ProviderSetupFailure.unsafePath
            case .resourceLimit: throw ProviderSetupFailure.resourceLimit
            case .unsupportedShape, .ownershipConflict, .malformedConfiguration, .unsupportedProvider:
                throw ProviderSetupFailure.ownershipConflict
            }
        }
        guard candidate != previous.data || nextOwnership != previousOwner.data else { return .unchanged }
        let transactionID = UUID()
        let temporaryName = ".notch-pet-\(transactionID.uuidString).tmp"
        let prepared = try configuration.prepare(candidate, name: temporaryName, preserving: previous, originalName: configurationName)
        var journalPublished = false
        defer {
            // Once intent is durable, only recovery may remove this transaction's candidate.
            if !journalPublished {
                configuration.discardTemporary(temporaryName, expected: prepared)
            } else if let intent = try? records.read(journalName, privateFile: true), intent.data == nil {
                configuration.discardTemporary(temporaryName, expected: prepared)
            }
        }
        let journal = HookJournal(version: 1, operation: operation, transactionID: transactionID,
            target: setupTarget, previousConfiguration: previous.digest,
            candidateConfiguration: HookFileSnapshot.hash(candidate), previousOwnership: previousOwner.data,
            previousOwnershipDigest: previousOwner.digest, nextOwnership: nextOwnership,
            nextOwnershipDigest: nextOwnership.map(HookFileSnapshot.hash), temporaryName: temporaryName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let journalData = try encoder.encode(journal)
        guard journalData.count <= HookFileDirectory.byteLimit else { throw ProviderSetupFailure.resourceLimit }
        try configuration.recheckIdentity()
        try records.recheckIdentity()
        guard previous.same(as: try configuration.read(configurationName)),
              previousOwner.same(as: try records.read(ownershipName, privateFile: true)),
              try records.read(journalName, privateFile: true).data == nil else { throw ProviderSetupFailure.changed }
        try Task.checkCancellation()
        // From this point cancellation cannot interrupt durable finalization. The UI can stop observing.
        // Mark before publication: a directory-sync failure can leave a published journal.
        journalPublished = true
        try records.replace(journalData, name: journalName)
        guard previous.same(as: try configuration.read(configurationName)),
              previousOwner.same(as: try records.read(ownershipName, privateFile: true)),
              try configuration.read(temporaryName).data == candidate else { throw ProviderSetupFailure.changed }
        try configuration.publish(temporaryName, as: configurationName, expected: prepared)
        try finalize(journal, configuration: configuration, records: records)
        return operation == .connect ? .installed : .removed
    }

    private func makePlan(_ input: HookSetupInput) -> HookSetupPlan {
        scope == .lifecycle ? HookSetupPlanner.plan(input) : ClaudeStatusLinePlanner.plan(input)
    }

    private func remove(configuration: Data?, ownership: Data?, target: HookSetupTarget) -> HookSetupPlan {
        scope == .lifecycle
            ? HookSetupPlanner.remove(configuration: configuration, ownership: ownership, target: target, agent: agent)
            : ClaudeStatusLinePlanner.remove(configuration: configuration, ownership: ownership, target: target)
    }

    private func validateOwner(_ data: Data, target: HookSetupTarget) throws -> UUID {
        if scope == .lifecycle { return try HookSetupPlanner.validatedOwnership(data, target: target, agent: agent).installationID }
        return try ClaudeStatusLinePlanner.validatedOwnership(data, target: target).installationID
    }

    private func verifyInstalled(_ configuration: Data, ownership: Data, target: HookSetupTarget) throws {
        if scope == .lifecycle { try HookSetupPlanner.verifyInstalled(configuration, ownership: ownership, target: target, agent: agent) }
        else { try ClaudeStatusLinePlanner.verifyInstalled(configuration, ownership: ownership, target: target) }
    }

    private func target(_ directory: HookFileDirectory, helper: String) -> HookSetupTarget {
        HookSetupTarget(configurationPath: directory.url.appendingPathComponent(configurationName).path,
                        parentDevice: directory.device, parentInode: directory.inode, helperPath: helper)
    }

    static func validateHelper(_ url: URL) throws {
        guard url.isFileURL else { throw ProviderSetupFailure.helperUnavailable }
        let directory = try HookFileDirectory(url.deletingLastPathComponent(), allowRootOwner: true)
        var info = stat()
        guard fstatat(directory.descriptor, url.lastPathComponent, &info, AT_SYMLINK_NOFOLLOW) == 0,
              info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o111 != 0,
              info.st_mode & 0o022 == 0, info.st_uid == getuid() || info.st_uid == 0 else {
            throw ProviderSetupFailure.helperUnavailable
        }
    }

    private func readJournal(_ data: Data, configuration: HookFileDirectory) throws -> HookJournal {
        let document = try HookConfigurationJSON(data: data)
        let allowed = ["version", "operation", "transactionID", "target", "previousConfiguration",
                       "candidateConfiguration", "previousOwnership", "previousOwnershipDigest",
                       "nextOwnership", "nextOwnershipDigest", "temporaryName"]
        // Codable omits absent optional members; unknown members remain conflicts.
        guard Set(document.members(at: []) ?? []).isSubset(of: Set(allowed.map(JSONPathComponent.key))) else {
            throw ProviderSetupFailure.recoveryRequired
        }
        let journal = try JSONDecoder().decode(HookJournal.self, from: data)
        guard document.rawValue(at: [.key("version")]) == Data("1".utf8),
              Set(document.members(at: [.key("target")]) ?? []) == Set(["configurationPath", "parentDevice", "parentInode", "helperPath"].map(JSONPathComponent.key)),
              journal.version == 1,
              journal.target == target(configuration, helper: journal.target.helperPath),
              journal.temporaryName == ".notch-pet-\(journal.transactionID.uuidString).tmp",
              journal.previousOwnership.map(HookFileSnapshot.hash) == journal.previousOwnershipDigest,
              journal.nextOwnership.map(HookFileSnapshot.hash) == journal.nextOwnershipDigest,
              validDigest(journal.candidateConfiguration),
              (journal.previousConfiguration.map { validDigest($0) } ?? true),
              journal.previousConfiguration != journal.candidateConfiguration else {
            throw ProviderSetupFailure.recoveryRequired
        }
        if let previous = journal.previousOwnership {
            _ = try validateOwner(previous, target: journal.target)
        }
        switch journal.operation {
        case .connect:
            guard let owner = journal.nextOwnership else { throw ProviderSetupFailure.recoveryRequired }
            _ = try validateOwner(owner, target: journal.target)
        case .remove:
            guard let owner = journal.previousOwnership, journal.nextOwnership == nil else {
                throw ProviderSetupFailure.recoveryRequired
            }
            _ = try validateOwner(owner, target: journal.target)
        }
        return journal
    }

    private func validDigest(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private func recover(configuration: HookFileDirectory, records: HookFileDirectory) throws {
        guard let data = try records.read(journalName, privateFile: true).data else {
            // Without durable intent a temporary basename alone proves no ownership.
            // Leave crash-orphaned storage inert; never adopt it as a configuration.
            return
        }
        do {
            let journal = try readJournal(data, configuration: configuration)
            let current = try configuration.read(configurationName)
            let owner = try records.read(ownershipName, privateFile: true)
            if current.digest == journal.previousConfiguration, owner.data == journal.previousOwnership {
                try cleanCandidate(journal, configuration: configuration)
                try records.remove(journalName)
                return
            }
            guard current.digest == journal.candidateConfiguration,
                  owner.data == journal.previousOwnership || owner.data == journal.nextOwnership else {
                throw ProviderSetupFailure.recoveryRequired
            }
            try finalize(journal, configuration: configuration, records: records)
        } catch {
            throw ProviderSetupFailure.recoveryRequired
        }
    }

    private func finalize(_ journal: HookJournal, configuration: HookFileDirectory,
                                 records: HookFileDirectory) throws {
        try configuration.recheckIdentity()
        try records.recheckIdentity()
        let current = try configuration.read(configurationName)
        guard current.digest == journal.candidateConfiguration, let hooks = current.data else {
            throw ProviderSetupFailure.recoveryRequired
        }
        if let next = journal.nextOwnership {
            try verifyInstalled(hooks, ownership: next, target: journal.target)
        } else {
            // No recognizable old helper invocation may survive a completed owned removal.
            guard case .unchanged = remove(configuration: hooks, ownership: nil, target: journal.target) else {
                throw ProviderSetupFailure.recoveryRequired
            }
        }
        let owner = try records.read(ownershipName, privateFile: true)
        guard owner.data == journal.previousOwnership || owner.data == journal.nextOwnership else {
            throw ProviderSetupFailure.recoveryRequired
        }
        try configuration.synchronizeFile(configurationName, expected: current)
        try HookFileDirectory.synchronize(configuration.descriptor)
        if owner.data != journal.nextOwnership {
            if let next = journal.nextOwnership { try records.replace(next, name: ownershipName) }
            else if owner.data != nil { try records.remove(ownershipName) }
        }
        guard (try configuration.read(configurationName)).same(as: current),
              try records.read(ownershipName, privateFile: true).data == journal.nextOwnership else {
            throw ProviderSetupFailure.recoveryRequired
        }
        let finalOwner = try records.read(ownershipName, privateFile: true)
        if finalOwner.data != nil { try records.synchronizeFile(ownershipName, expected: finalOwner) }
        try HookFileDirectory.synchronize(records.descriptor)
        try cleanCandidate(journal, configuration: configuration)
        try records.remove(journalName)
    }

    private func cleanCandidate(_ journal: HookJournal, configuration: HookFileDirectory) throws {
        let snapshot = try configuration.read(journal.temporaryName)
        guard snapshot.data != nil else { return }
        guard snapshot.digest == journal.candidateConfiguration else { throw ProviderSetupFailure.recoveryRequired }
        try configuration.remove(journal.temporaryName)
    }

}
