import EventBridge
import Foundation

public enum ProviderHookEnablement: Equatable, Sendable {
    case enabled, disabled, managedOnly, unverified
}

/// A release may be registered only after its syntax, policy probe, timeout and trust flow qualify.
/// The probe must inspect the supplied executable/configuration context with bounded, read-only I/O.
public struct CodexHookQualification: Sendable {
    public let inspectPolicy: @Sendable (URL, URL) async -> ProviderHookEnablement

    public init(inspectPolicy: @escaping @Sendable (URL, URL) async -> ProviderHookEnablement) {
        self.inspectPolicy = inspectPolicy
    }
}

public enum OwnedProviderHooks: Equatable, Sendable {
    case notOwned, owned, conflict, recoveryRequired
}

public struct ProviderSetupInspection: Sendable {
    public let health: IntegrationHealthEvidence
    public let ownership: OwnedProviderHooks
    public let installationUnavailable: ProviderSetupFailure?
    public let policy: ProviderHookEnablement
    public let runtimeQualified: Bool
}

public enum ProviderSetupStage: Equatable, Sendable {
    case checking, saving, verifying
}

public struct ProviderSetupResult: Sendable {
    public let change: ProviderSetupChange
    public let inspection: ProviderSetupInspection
}

/// No account methods, transcript reads, config.toml writes, trust grants or agent turns.
public struct ProviderSetupService: Sendable {
    // Deliberately empty until release qualification is authorized and recorded.
    // Historical version strings are not evidence of effective policy or enforced hook timeouts.
    public static let qualifiedReleases: [String: CodexHookQualification] = [:]
    private let releases: [String: CodexHookQualification]

    public init(releases: [String: CodexHookQualification] = ProviderSetupService.qualifiedReleases) {
        self.releases = releases
    }

    public func check(_ context: ProviderSetupContext) async -> ProviderSetupInspection {
        await check(context, preflight: nil)
    }

    func check(_ context: ProviderSetupContext, preflight: ProviderSetupInspection?) async -> ProviderSetupInspection {
        let safety = Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return false }
            do {
                if try HookFileDirectory.exists(context.configurationDirectory) {
                    _ = try HookFileDirectory(context.configurationDirectory)
                } else {
                    _ = try HookFileDirectory(context.configurationDirectory.deletingLastPathComponent())
                }
                return true
            } catch { return false }
        }
        let safeDirectory = await withTaskCancellationHandler(operation: { await safety.value }, onCancel: { safety.cancel() })
        guard safeDirectory, !Task.isCancelled else {
            return ProviderSetupInspection(health: IntegrationHealthEvidence(agent: context.agent,
                configuration: .unavailable(.unsupportedShape)), ownership: .conflict,
                installationUnavailable: .unsafePath, policy: .unverified, runtimeQualified: false)
        }
        var health = await IntegrationHealthProbe.inspect(agent: context.agent,
            executableURL: preflight == nil ? context.executableURL : nil,
            configurationURL: context.configurationDirectory.appendingPathComponent(ProviderHookPolicy.configurationName(context.agent)),
            helperURL: context.helperURL)
        // Only reuse evidence within this operation. Configuration and ownership are always read again.
        if let preflight { health.version = preflight.health.version }
        let worker = Task.detached(priority: .utility) {
            Self.inspectOwnership(context)
        }
        let ownership = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
        let support: (ProviderSetupFailure?, ProviderHookEnablement, Bool)
        if let preflight {
            support = (health.helper == .available ? preflight.installationUnavailable : .helperUnavailable,
                       preflight.policy, preflight.runtimeQualified)
        } else {
            support = await inspectSupport(context, health: health)
        }
        return ProviderSetupInspection(health: health, ownership: ownership, installationUnavailable: support.0,
                                       policy: support.1, runtimeQualified: support.2)
    }

    public func execute(_ operation: ProviderSetupOperation, context: ProviderSetupContext) async throws -> ProviderSetupChange {
        try await executeAndInspect(operation, context: context).change
    }

    public func executeAndInspect(_ operation: ProviderSetupOperation, context: ProviderSetupContext,
                                 progress: @Sendable (ProviderSetupStage) async -> Void = { _ in }) async throws -> ProviderSetupResult {
        try Task.checkCancellation()
        let support: HookSetupSupport
        let preflight: ProviderSetupInspection?
        if operation == .connect {
            await progress(.checking)
            let inspection = await check(context)
            preflight = inspection
            try Task.checkCancellation()
            if let failure = inspection.installationUnavailable { throw failure }
            guard case .reported(let version) = inspection.health.version else {
                throw ProviderSetupFailure.unqualifiedVersion
            }
            support = inspection.runtimeQualified
                ? .verified(version: version, hooksEnabled: true, helperAvailable: true)
                : .documented(version: version, helperAvailable: true)
        } else {
            // Safe removal must remain available when the CLI disappears or policy changes.
            support = .unverified
            preflight = nil
        }
        try Task.checkCancellation()
        await progress(.saving)
        let worker = Task.detached(priority: .utility) {
            try ProviderHookTransaction(agent: context.agent, scope: context.scope).run(operation, context: context, support: support)
        }
        let change = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
        try Task.checkCancellation()
        await progress(.verifying)
        let inspection = await check(context, preflight: preflight)
        try Task.checkCancellation()
        return ProviderSetupResult(change: change, inspection: inspection)
    }

    private func inspectSupport(_ context: ProviderSetupContext, health: IntegrationHealthEvidence)
        async -> (ProviderSetupFailure?, ProviderHookEnablement, Bool) {
        guard !Task.isCancelled else { return (.enablementUnverified, .unverified, false) }
        guard health.helper == .available else { return (.helperUnavailable, .unverified, false) }
        // Say the program is missing rather than reporting its version as unsupported.
        guard context.executableURL != nil else { return (.executableNotFound, .unverified, false) }
        guard case .reported(let version) = health.version, let executable = context.executableURL else {
            return (.unqualifiedVersion, .unverified, false)
        }
        let qualification = context.agent == .codex ? releases[version] : nil
        guard qualification != nil || ProviderHookPolicy.supportsDocumented(version, agent: context.agent) else {
            return (.unqualifiedVersion, .unverified, false)
        }
        let policy: ProviderHookEnablement
        if let qualification {
            policy = await qualification.inspectPolicy(executable, context.configurationDirectory)
        } else if context.agent == .codex {
            policy = await CodexHookPolicyProbe.inspect(executable: executable, configuration: context.configurationDirectory)
        } else {
            let worker = Task.detached(priority: .utility) { Self.inspectClaudePolicy(context) }
            policy = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
        }
        switch policy {
        case .disabled: return (.hooksDisabled, policy, false)
        case .managedOnly: return (.managedHooksOnly, policy, false)
        case .enabled: return (nil, policy, qualification != nil)
        case .unverified:
            return (ProviderHookPolicy.supportsDocumented(version, agent: context.agent) ? nil : .enablementUnverified,
                    policy, false)
        }
    }

    private static func inspectClaudePolicy(_ context: ProviderSetupContext) -> ProviderHookEnablement {
        guard !Task.isCancelled else { return .unverified }
        do {
            guard try HookFileDirectory.exists(context.configurationDirectory) else { return .unverified }
            let directory = try HookFileDirectory(context.configurationDirectory)
            guard let data = try directory.read("settings.json").data else { return .unverified }
            let document = try HookConfigurationJSON(data: data)
            if document.rawValue(at: [.key("disableAllHooks")]) == Data("true".utf8) { return .disabled }
            if document.rawValue(at: [.key("allowManagedHooksOnly")]) == Data("true".utf8) { return .managedOnly }
            // User settings alone cannot establish effective project/managed policy.
            return .unverified
        } catch { return .unverified }
    }

    private static func inspectOwnership(_ context: ProviderSetupContext) -> OwnedProviderHooks {
        guard !Task.isCancelled else { return .conflict }
        do {
            let name = ProviderHookPolicy.configurationName(context.agent)
            guard try HookFileDirectory.exists(context.configurationDirectory) else {
                return try HookFileDirectory.exists(context.ownershipDirectory) ? .conflict : .notOwned
            }
            let configuration = try HookFileDirectory(context.configurationDirectory)
            let hooks = try configuration.read(name)
            guard try HookFileDirectory.exists(context.ownershipDirectory) else {
                let target = HookSetupTarget(configurationPath: context.configurationDirectory.appendingPathComponent(name).path,
                    parentDevice: configuration.device, parentInode: configuration.inode, helperPath: context.helperURL.path)
                if case .unchanged = removalPlan(context, configuration: hooks.data, target: target) {
                    return .notOwned
                }
                return .conflict
            }
            let records = try HookFileDirectory(context.ownershipDirectory, privateDirectory: true)
            let pending = context.scope.journalName
            let ownership = context.scope.ownershipName
            let pendingNames = context.agent == .claude ? ProviderSetupScope.allCases.map(\.journalName) : [pending]
            for name in pendingNames {
                if try records.read(name, privateFile: true).data != nil { return .recoveryRequired }
            }
            guard let owner = try records.read(ownership, privateFile: true).data else {
                let target = HookSetupTarget(configurationPath: context.configurationDirectory.appendingPathComponent(name).path,
                    parentDevice: configuration.device, parentInode: configuration.inode, helperPath: context.helperURL.path)
                guard case .unchanged = removalPlan(context, configuration: hooks.data, target: target) else {
                    return .conflict
                }
                return .notOwned
            }
            _ = try HookConfigurationJSON(data: owner)
            let record = try JSONDecoder().decode(HookOwnershipHeader.self, from: owner)
            let target = HookSetupTarget(configurationPath: context.configurationDirectory.appendingPathComponent(name).path,
                parentDevice: configuration.device, parentInode: configuration.inode, helperPath: record.target.helperPath)
            guard let hooks = hooks.data else { return .conflict }
            if context.scope == .claudeQuota { try ClaudeStatusLinePlanner.verifyInstalled(hooks, ownership: owner, target: target) }
            else { try HookSetupPlanner.verifyInstalled(hooks, ownership: owner, target: target, agent: context.agent,
                                                        interactive: context.scope == .claudeActions) }
            guard record.target.helperPath == context.helperURL.path else { return .conflict }
            return .owned
        } catch {
            return .conflict
        }
    }

    private static func removalPlan(_ context: ProviderSetupContext, configuration: Data?, target: HookSetupTarget) -> HookSetupPlan {
        context.scope == .claudeQuota ? ClaudeStatusLinePlanner.remove(configuration: configuration, ownership: nil, target: target)
            : HookSetupPlanner.remove(configuration: configuration, ownership: nil, target: target, agent: context.agent,
                                      interactive: context.scope == .claudeActions)
    }
}
