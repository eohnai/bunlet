import CryptoKit
import Darwin
import EventBridge
import Foundation
import Integration
import Observation

enum ProviderSetupAction: Equatable {
    case connect, repair, check, remove, disconnect
    case connectQuota, checkQuota, removeQuota

    var scope: ProviderSetupScope {
        switch self {
        case .connectQuota, .checkQuota, .removeQuota: .claudeQuota
        default: .lifecycle
        }
    }

    var isCheck: Bool { self == .check || self == .checkQuota }
    var removes: Bool { self == .remove || self == .disconnect || self == .removeQuota }
}

/// View-owned action state, separate from configuration, delivery and live session truth.
@MainActor
@Observable
final class ProviderSetupController {
    let agent: Agent
    var providerName: String { agent == .codex ? "Codex" : "Claude Code" }
    private(set) var operation: ProviderSetupAction?
    private(set) var inspection: ProviderSetupInspection?
    private(set) var quotaInspection: ProviderSetupInspection?
    private(set) var confirmation: ProviderSetupAction?
    private(set) var message = "Check a provider to inspect setup. Connecting is optional."
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let service: ProviderSetupService
    @ObservationIgnored private let onConnected: () -> Void
    @ObservationIgnored private let onPaused: () -> Void
    @ObservationIgnored private let onInspection: (IntegrationHealthEvidence) -> Void

    init(agent: Agent = .codex, service: ProviderSetupService = ProviderSetupService(),
         onConnected: @escaping () -> Void, onPaused: @escaping () -> Void = {},
         onInspection: @escaping (IntegrationHealthEvidence) -> Void) {
        self.agent = agent
        self.onPaused = onPaused
        self.service = service
        self.onConnected = onConnected
        self.onInspection = onInspection
        message = "Check \(providerName) to inspect setup. Connecting is optional."
    }

    func start(_ action: ProviderSetupAction) {
        guard task == nil else { return }
        let current = UUID()
        generation = current
        operation = action
        guard action.scope == .lifecycle || agent == .claude else {
            operation = nil
            return
        }
        let removing = action.removes
        if action == .disconnect { onPaused() }
        let targetName = action.scope == .claudeQuota ? "quota forwarding" : "hooks"
        message = action.isCheck ? "Checking \(providerName) \(targetName)…" : "Updating owned \(providerName) \(targetName)…"
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.generation == current {
                    self.operation = nil
                    self.task = nil
                }
            }
            var disconnectedQuota = false
            do {
                let context = try self.context(needsExecutable: !removing, scope: action.scope)
                ServiceStartLedger.record(.configurationProbe)
                if action.isCheck {
                    let result = await self.service.check(context)
                    try Task.checkCancellation()
                    guard self.generation == current else { return }
                    self.record(result, scope: action.scope)
                    if action.scope == .lifecycle { self.onInspection(result.health) }
                    self.message = Self.summary(result)
                } else {
                    if action.scope == .lifecycle { self.inspection = nil }
                    else { self.quotaInspection = nil }
                    if action == .disconnect, self.agent == .claude {
                        self.quotaInspection = nil
                        let quotaContext = try self.context(needsExecutable: false, scope: .claudeQuota)
                        _ = try await self.service.execute(.remove, context: quotaContext)
                        disconnectedQuota = true
                        try Task.checkCancellation()
                        self.quotaInspection = await self.service.check(quotaContext)
                        try Task.checkCancellation()
                    }
                    let change = try await self.service.execute(removing ? .remove : .connect, context: context)
                    try Task.checkCancellation()
                    guard self.generation == current else { return }
                    if !removing { self.onConnected() }
                    switch change {
                    case .installed:
                        self.message = "Owned \(targetName) installed. Complete \(self.providerName)’s normal hook/workspace review. Runtime support and provider delivery remain unverified."
                    case .removed:
                        self.message = "Owned \(targetName) removed. The original status line is restored when removing quota forwarding."
                    case .unchanged:
                        self.message = !removing ? "Owned \(targetName) unchanged. Provider delivery is separate from installation."
                            : "No owned \(targetName) needed removal."
                    }
                    if action == .disconnect {
                        self.message = "Owned integration entries removed where present. This provider remains paused; retained requests are unconfirmed."
                    }
                    let result = await self.service.check(context)
                    try Task.checkCancellation()
                    guard self.generation == current else { return }
                    self.record(result, scope: action.scope)
                    if action.scope == .lifecycle { self.onInspection(result.health) }
                }
            } catch is CancellationError {
                if self.generation == current {
                    self.message = "Stopped observing this operation. If saving had begun, use Check before retrying."
                    if disconnectedQuota { self.message += " Quota forwarding was already removed; this provider remains paused." }
                }
            } catch let failure as ProviderSetupFailure {
                if self.generation == current {
                    self.message = Self.explanation(failure, agent: self.agent)
                    if disconnectedQuota { self.message += " Quota forwarding was already removed; this provider remains paused. Use Check before retrying." }
                }
            } catch {
                if self.generation == current {
                    self.message = "Setup could not finish. Use Check before retrying; no automatic recovery over uncertain changes is attempted."
                    if disconnectedQuota { self.message += " Quota forwarding was already removed; this provider remains paused." }
                }
            }
        }
    }

    func requestConfirmation(_ action: ProviderSetupAction) {
        guard operation == nil else { return }
        confirmation = action
    }

    func dismissConfirmation() { confirmation = nil }

    func cancel() {
        confirmation = nil
        guard task != nil else { return }
        task?.cancel()
        message = "Cancelling observation. An already-started save will finish or leave recovery evidence."
        // Keep the handle until the worker exits: a second click must not race a durable write.
    }

    private func record(_ result: ProviderSetupInspection, scope: ProviderSetupScope) {
        if scope == .lifecycle { inspection = result }
        else { quotaInspection = result }
    }

    private func context(needsExecutable: Bool, scope: ProviderSetupScope = .lifecycle) throws -> ProviderSetupContext {
        let manager = FileManager.default
        let override = try environmentValue(agent == .codex ? "CODEX_HOME" : "CLAUDE_CONFIG_DIR", limit: 4096)
        let executable: URL?
        if needsExecutable {
            let searchPath = try environmentValue("PATH", limit: 16_384)
            switch AgentPathLocator.executable(agent: agent, policy: .health, searchPath: searchPath,
                                              homeDirectory: manager.homeDirectoryForCurrentUser) {
            case .found(let url): executable = url
            case .notFound, .invalidSearchPath: executable = nil
            }
        } else {
            executable = nil
        }
        guard let directory = AgentPathLocator.configurationDirectory(agent: agent, override: override,
                  homeDirectory: manager.homeDirectoryForCurrentUser),
              let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent(),
              let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ProviderSetupFailure.unsafePath
        }
        let identity = SHA256.hash(data: Data(directory.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return ProviderSetupContext(configurationDirectory: directory,
            ownershipDirectory: support.appendingPathComponent(agent == .codex ? "NotchPet/Integrations/Codex" : "NotchPet/Integrations/Claude").appendingPathComponent(identity),
            helperURL: executableDirectory.appendingPathComponent(scope == .lifecycle ? "NotchPetHook" : "NotchPetStatusLine"),
            executableURL: executable, agent: agent, scope: scope)
    }

    private func environmentValue(_ key: String, limit: Int) throws -> String? {
        guard let value = getenv(key) else { return nil }
        guard strnlen(value, limit + 1) <= limit else { throw ProviderSetupFailure.resourceLimit }
        return String(cString: value)
    }

    private static func summary(_ inspection: ProviderSetupInspection) -> String {
        switch inspection.ownership {
        case .recoveryRequired:
            return "A saved operation needs recovery. Finish other configuration edits, then explicitly retry Connect or Remove hooks. Conflicting states require manual reconciliation."
        case .conflict:
            return "Hook ownership or configuration conflicts with the saved record. Leave the files in place for manual reconciliation."
        case .owned:
            return "Owned entries match. Trust, receiver readiness and actual delivery remain separate evidence."
        case .notOwned:
            return inspection.installationUnavailable.map { explanation($0, agent: inspection.health.agent) } ?? "No owned entries. Connect can install this app’s entries."
        }
    }

    static func explanation(_ failure: ProviderSetupFailure, agent: Agent = .codex) -> String {
        let name = agent == .codex ? "Codex" : "Claude Code"
        switch failure {
        case .unqualifiedVersion:
            return "This \(name) version has no documented setup binding. Configuration was not changed."
        case .enablementUnverified:
            return "Effective \(name) hook policy could not be established for this setup binding."
        case .hooksDisabled:
            return "\(name) hooks are disabled in the inspected policy/settings. Review the provider settings before connecting."
        case .managedHooksOnly:
            return "\(name) policy allows managed hooks only. Contact your administrator about user hooks."
        case .helperUnavailable:
            return "The bundled hook helper is unavailable or unsafe. Reinstall the app before connecting."
        case .busy:
            return "Another setup operation is using these records. Wait for it to finish, then use Check."
        case .changed, .ownershipConflict:
            return "Configuration or ownership changed. Finish other configuration edits and use Check; conflicting entries need manual reconciliation."
        case .recoveryRequired, .durabilityUncertain:
            return "The saved result is uncertain. Keep configuration and recovery records intact. Use Check, then explicitly retry; unknown states need manual reconciliation."
        case .unsafePath, .unsafeMetadata:
            return "The configuration path or its permissions are unsafe for automatic changes. Files were left for review."
        case .resourceLimit:
            return "Setup input or recovery records exceed the supported size. Automatic setup stopped."
        case .unreadable, .writeFailed:
            return "Setup could not read or save its files. Use Check before retrying; preserve any recovery records."
        }
    }
}
