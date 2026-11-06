import Darwin
import Foundation
import EventBridge

public enum CodexSetupOperation: String, Codable, Sendable {
    case connect, remove
}

public enum CodexSetupChange: Equatable, Sendable {
    case installed, removed, unchanged
}

public struct CodexSetupContext: Sendable {
    public let configurationDirectory: URL
    public let ownershipDirectory: URL
    public let helperURL: URL
    public let executableURL: URL?

    public init(configurationDirectory: URL, ownershipDirectory: URL, helperURL: URL, executableURL: URL?) {
        self.configurationDirectory = configurationDirectory
        self.ownershipDirectory = ownershipDirectory
        self.helperURL = helperURL
        self.executableURL = executableURL
    }
}

private struct HookJournal: Codable {
    let version: Int
    let operation: CodexSetupOperation
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

/// The app never invokes this from startup. A user operation owns the worker, lock and transaction.
enum CodexHookTransaction {
    static let ownershipName = "ownership-v1.json"
    static let journalName = "pending-v1.json"
    static let configurationName = "hooks.json"

    static func run(_ operation: CodexSetupOperation, context: CodexSetupContext,
                    support: HookSetupSupport) throws -> CodexSetupChange {
        try Task.checkCancellation()
        let configuration = try HookFileDirectory(context.configurationDirectory)
        // Remove without an owned record requires no new directories or lock files.
        if operation == .remove, !(try HookFileDirectory.exists(context.ownershipDirectory)) {
            let current = try configuration.read(configurationName)
            let target = target(configuration, helper: context.helperURL.path)
            guard case .unchanged = HookSetupPlanner.remove(configuration: current.data, ownership: nil, target: target) else {
                throw CodexSetupFailure.ownershipConflict
            }
            return .unchanged
        }
        let records = try HookFileDirectory(context.ownershipDirectory, create: operation == .connect, privateDirectory: true)
        let lock = try records.lock()
        defer { _ = flock(lock, LOCK_UN); close(lock) }
        try recover(configuration: configuration, records: records)
        try Task.checkCancellation()
        let previous = try configuration.read(configurationName)
        let previousOwner = try records.read(ownershipName, privateFile: true)
        let setupTarget: HookSetupTarget
        let plan: HookSetupPlan
        if operation == .connect {
            try validateHelper(context.helperURL)
            setupTarget = target(configuration, helper: context.helperURL.path)
            let installationID: UUID
            if let owner = previousOwner.data {
                installationID = try HookSetupPlanner.validatedOwnership(owner, target: setupTarget).installationID
            } else {
                installationID = UUID()
            }
            plan = HookSetupPlanner.plan(HookSetupInput(agent: .codex, configuration: previous.data,
                ownership: previousOwner.data, target: setupTarget, support: support, installationID: installationID))
        } else {
            if let bytes = previousOwner.data {
                _ = try HookConfigurationJSON(data: bytes)
                let owner = try JSONDecoder().decode(HookSetupOwnership.self, from: bytes)
                setupTarget = target(configuration, helper: owner.target.helperPath)
            } else {
                setupTarget = target(configuration, helper: context.helperURL.path)
            }
            plan = HookSetupPlanner.remove(configuration: previous.data, ownership: previousOwner.data, target: setupTarget)
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
            throw CodexSetupFailure.ownershipConflict
        case .unavailable(let failure):
            switch failure {
            case .unverifiedVersion, .unsupportedVersion: throw CodexSetupFailure.unqualifiedVersion
            case .hooksDisabled: throw CodexSetupFailure.hooksDisabled
            case .helperUnavailable: throw CodexSetupFailure.helperUnavailable
            case .unsafeTarget: throw CodexSetupFailure.unsafePath
            case .resourceLimit: throw CodexSetupFailure.resourceLimit
            case .unsupportedShape, .ownershipConflict, .malformedConfiguration, .unsupportedProvider:
                throw CodexSetupFailure.ownershipConflict
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
        guard journalData.count <= HookFileDirectory.byteLimit else { throw CodexSetupFailure.resourceLimit }
        try configuration.recheckIdentity()
        try records.recheckIdentity()
        guard previous.same(as: try configuration.read(configurationName)),
              previousOwner.same(as: try records.read(ownershipName, privateFile: true)),
              try records.read(journalName, privateFile: true).data == nil else { throw CodexSetupFailure.changed }
        try Task.checkCancellation()
        // From this point cancellation cannot interrupt durable finalization. The UI can stop observing.
        // Mark before publication: a directory-sync failure can leave a published journal.
        journalPublished = true
        try records.replace(journalData, name: journalName)
        guard previous.same(as: try configuration.read(configurationName)),
              previousOwner.same(as: try records.read(ownershipName, privateFile: true)),
              try configuration.read(temporaryName).data == candidate else { throw CodexSetupFailure.changed }
        try configuration.publish(temporaryName, as: configurationName, expected: prepared)
        try finalize(journal, configuration: configuration, records: records)
        return operation == .connect ? .installed : .removed
    }

    private static func target(_ directory: HookFileDirectory, helper: String) -> HookSetupTarget {
        HookSetupTarget(configurationPath: directory.url.appendingPathComponent(configurationName).path,
                        parentDevice: directory.device, parentInode: directory.inode, helperPath: helper)
    }

    static func validateHelper(_ url: URL) throws {
        guard url.isFileURL else { throw CodexSetupFailure.helperUnavailable }
        let directory = try HookFileDirectory(url.deletingLastPathComponent(), allowRootOwner: true)
        var info = stat()
        guard fstatat(directory.descriptor, url.lastPathComponent, &info, AT_SYMLINK_NOFOLLOW) == 0,
              info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o111 != 0,
              info.st_mode & 0o022 == 0, info.st_uid == getuid() || info.st_uid == 0 else {
            throw CodexSetupFailure.helperUnavailable
        }
    }

    private static func readJournal(_ data: Data, configuration: HookFileDirectory) throws -> HookJournal {
        let document = try HookConfigurationJSON(data: data)
        let allowed = ["version", "operation", "transactionID", "target", "previousConfiguration",
                       "candidateConfiguration", "previousOwnership", "previousOwnershipDigest",
                       "nextOwnership", "nextOwnershipDigest", "temporaryName"]
        // Codable omits absent optional members; unknown members remain conflicts.
        guard Set(document.members(at: []) ?? []).isSubset(of: Set(allowed.map(JSONPathComponent.key))) else {
            throw CodexSetupFailure.recoveryRequired
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
              journal.previousConfiguration.map(validDigest) ?? true,
              journal.previousConfiguration != journal.candidateConfiguration else {
            throw CodexSetupFailure.recoveryRequired
        }
        if let previous = journal.previousOwnership {
            _ = try HookSetupPlanner.validatedOwnership(previous, target: journal.target)
        }
        switch journal.operation {
        case .connect:
            guard let owner = journal.nextOwnership else { throw CodexSetupFailure.recoveryRequired }
            _ = try HookSetupPlanner.validatedOwnership(owner, target: journal.target)
        case .remove:
            guard let owner = journal.previousOwnership, journal.nextOwnership == nil else {
                throw CodexSetupFailure.recoveryRequired
            }
            _ = try HookSetupPlanner.validatedOwnership(owner, target: journal.target)
        }
        return journal
    }

    private static func validDigest(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func recover(configuration: HookFileDirectory, records: HookFileDirectory) throws {
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
                throw CodexSetupFailure.recoveryRequired
            }
            try finalize(journal, configuration: configuration, records: records)
        } catch {
            throw CodexSetupFailure.recoveryRequired
        }
    }

    private static func finalize(_ journal: HookJournal, configuration: HookFileDirectory,
                                 records: HookFileDirectory) throws {
        try configuration.recheckIdentity()
        try records.recheckIdentity()
        let current = try configuration.read(configurationName)
        guard current.digest == journal.candidateConfiguration, let hooks = current.data else {
            throw CodexSetupFailure.recoveryRequired
        }
        if let next = journal.nextOwnership {
            try HookSetupPlanner.verifyInstalled(hooks, ownership: next, target: journal.target)
        } else {
            // No recognizable old helper invocation may survive a completed owned removal.
            guard case .unchanged = HookSetupPlanner.remove(configuration: hooks, ownership: nil, target: journal.target) else {
                throw CodexSetupFailure.recoveryRequired
            }
        }
        let owner = try records.read(ownershipName, privateFile: true)
        guard owner.data == journal.previousOwnership || owner.data == journal.nextOwnership else {
            throw CodexSetupFailure.recoveryRequired
        }
        try configuration.synchronizeFile(configurationName, expected: current)
        try HookFileDirectory.synchronize(configuration.descriptor)
        if owner.data != journal.nextOwnership {
            if let next = journal.nextOwnership { try records.replace(next, name: ownershipName) }
            else if owner.data != nil { try records.remove(ownershipName) }
        }
        guard (try configuration.read(configurationName)).same(as: current),
              try records.read(ownershipName, privateFile: true).data == journal.nextOwnership else {
            throw CodexSetupFailure.recoveryRequired
        }
        let finalOwner = try records.read(ownershipName, privateFile: true)
        if finalOwner.data != nil { try records.synchronizeFile(ownershipName, expected: finalOwner) }
        try HookFileDirectory.synchronize(records.descriptor)
        try cleanCandidate(journal, configuration: configuration)
        try records.remove(journalName)
    }

    private static func cleanCandidate(_ journal: HookJournal, configuration: HookFileDirectory) throws {
        let snapshot = try configuration.read(journal.temporaryName)
        guard snapshot.data != nil else { return }
        guard snapshot.digest == journal.candidateConfiguration else { throw CodexSetupFailure.recoveryRequired }
        try configuration.remove(journal.temporaryName)
    }

}
