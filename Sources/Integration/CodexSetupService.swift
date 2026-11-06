import EventBridge
import Foundation

public enum CodexEffectiveHookPolicy: Sendable {
    case enabled, disabled, managedOnly, unverified
}

/// A release may be registered only after its syntax, policy probe, timeout and trust flow qualify.
/// The probe must inspect the supplied executable/configuration context with bounded, read-only I/O.
public struct CodexHookQualification: Sendable {
    public let inspectPolicy: @Sendable (URL, URL) async -> CodexEffectiveHookPolicy

    public init(inspectPolicy: @escaping @Sendable (URL, URL) async -> CodexEffectiveHookPolicy) {
        self.inspectPolicy = inspectPolicy
    }
}

public enum CodexOwnedHooks: Equatable, Sendable {
    case notOwned, owned, conflict, recoveryRequired
}

public struct CodexSetupInspection: Sendable {
    public let health: IntegrationHealthEvidence
    public let ownership: CodexOwnedHooks
    public let installationUnavailable: CodexSetupFailure?
}

/// No account access, transcript reads, config.toml writes, trust grants or agent turns.
public struct CodexSetupService: Sendable {
    // Deliberately empty until release qualification is authorized and recorded.
    // Historical version strings are not evidence of effective policy or enforced hook timeouts.
    public static let qualifiedReleases: [String: CodexHookQualification] = [:]
    private let releases: [String: CodexHookQualification]

    public init(releases: [String: CodexHookQualification] = CodexSetupService.qualifiedReleases) {
        self.releases = releases
    }

    public func check(_ context: CodexSetupContext) async -> CodexSetupInspection {
        let safety = Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return false }
            return (try? HookFileDirectory(context.configurationDirectory)) != nil
        }
        let safeDirectory = await withTaskCancellationHandler(operation: { await safety.value }, onCancel: { safety.cancel() })
        guard safeDirectory, !Task.isCancelled else {
            return CodexSetupInspection(health: IntegrationHealthEvidence(agent: .codex,
                configuration: .unavailable(.unsupportedShape)), ownership: .conflict, installationUnavailable: .unsafePath)
        }
        let health = await IntegrationHealthProbe.inspect(agent: .codex, executableURL: context.executableURL,
            configurationURL: context.configurationDirectory.appendingPathComponent("hooks.json"),
            helperURL: context.helperURL)
        let worker = Task.detached(priority: .utility) {
            Self.inspectOwnership(context)
        }
        let ownership = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
        let unavailable = await supportFailure(context, health: health)
        return CodexSetupInspection(health: health, ownership: ownership, installationUnavailable: unavailable)
    }

    public func execute(_ operation: CodexSetupOperation, context: CodexSetupContext) async throws -> CodexSetupChange {
        try Task.checkCancellation()
        let support: HookSetupSupport
        if operation == .connect {
            let inspection = await check(context)
            try Task.checkCancellation()
            if let failure = inspection.installationUnavailable { throw failure }
            guard case .reported(let version) = inspection.health.version else {
                throw CodexSetupFailure.unqualifiedVersion
            }
            support = .verified(version: version, hooksEnabled: true, helperAvailable: true)
        } else {
            // Safe removal must remain available when the CLI disappears or policy changes.
            support = .unverified
        }
        let worker = Task.detached(priority: .utility) {
            try CodexHookTransaction.run(operation, context: context, support: support)
        }
        return try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    }

    private func supportFailure(_ context: CodexSetupContext, health: IntegrationHealthEvidence) async -> CodexSetupFailure? {
        guard !Task.isCancelled else { return .enablementUnverified }
        guard health.helper == .available else { return .helperUnavailable }
        guard case .reported(let version) = health.version, let release = releases[version],
              let executable = context.executableURL else { return .unqualifiedVersion }
        switch await release.inspectPolicy(executable, context.configurationDirectory) {
        case .enabled: return nil
        case .disabled: return .hooksDisabled
        case .managedOnly: return .managedHooksOnly
        case .unverified: return .enablementUnverified
        }
    }

    private static func inspectOwnership(_ context: CodexSetupContext) -> CodexOwnedHooks {
        guard !Task.isCancelled else { return .conflict }
        do {
            let configuration = try HookFileDirectory(context.configurationDirectory)
            let hooks = try configuration.read("hooks.json")
            guard try HookFileDirectory.exists(context.ownershipDirectory) else {
                let target = HookSetupTarget(configurationPath: context.configurationDirectory.appendingPathComponent("hooks.json").path,
                    parentDevice: configuration.device, parentInode: configuration.inode, helperPath: context.helperURL.path)
                if case .unchanged = HookSetupPlanner.remove(configuration: hooks.data, ownership: nil, target: target) {
                    return .notOwned
                }
                return .conflict
            }
            let records = try HookFileDirectory(context.ownershipDirectory, privateDirectory: true)
            if try records.read("pending-v1.json", privateFile: true).data != nil { return .recoveryRequired }
            guard let owner = try records.read("ownership-v1.json", privateFile: true).data else {
                let target = HookSetupTarget(configurationPath: context.configurationDirectory.appendingPathComponent("hooks.json").path,
                    parentDevice: configuration.device, parentInode: configuration.inode, helperPath: context.helperURL.path)
                guard case .unchanged = HookSetupPlanner.remove(configuration: hooks.data, ownership: nil, target: target) else {
                    return .conflict
                }
                return .notOwned
            }
            _ = try HookConfigurationJSON(data: owner)
            let record = try JSONDecoder().decode(HookSetupOwnership.self, from: owner)
            let target = HookSetupTarget(configurationPath: context.configurationDirectory.appendingPathComponent("hooks.json").path,
                parentDevice: configuration.device, parentInode: configuration.inode, helperPath: record.target.helperPath)
            guard let hooks = hooks.data else { return .conflict }
            try HookSetupPlanner.verifyInstalled(hooks, ownership: owner, target: target)
            return .owned
        } catch {
            return .conflict
        }
    }
}
