import CryptoKit
import Darwin
import EventBridge
import Foundation
import Integration
import Observation

enum ProviderSetupAction: Equatable {
    case connect, repair, check, remove, disconnect
    case connectQuota, checkQuota, removeQuota
    case connectActions, checkActions, removeActions

    var scope: ProviderSetupScope {
        switch self {
        case .connectQuota, .checkQuota, .removeQuota: .claudeQuota
        case .connectActions, .checkActions, .removeActions: .claudeActions
        default: .lifecycle
        }
    }

    var isCheck: Bool { self == .check || self == .checkQuota || self == .checkActions }
    var removes: Bool { self == .remove || self == .disconnect || self == .removeQuota || self == .removeActions }
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
    private(set) var actionInspection: ProviderSetupInspection?
    private(set) var confirmation: ProviderSetupAction?
    private(set) var message = "Check a provider to inspect setup. Connecting is optional."
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let service: ProviderSetupService
    @ObservationIgnored private let onConnected: () -> Void
    @ObservationIgnored private let onPaused: () -> Void
    @ObservationIgnored private let onActionsConsent: (Bool) -> Void
    @ObservationIgnored private let onInspection: (IntegrationHealthEvidence) -> Void

    init(agent: Agent = .codex, service: ProviderSetupService = ProviderSetupService(),
         onConnected: @escaping () -> Void, onPaused: @escaping () -> Void = {},
         onActionsConsent: @escaping (Bool) -> Void = { _ in },
         onInspection: @escaping (IntegrationHealthEvidence) -> Void) {
        self.agent = agent
        self.onPaused = onPaused
        self.onActionsConsent = onActionsConsent
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
        if action == .removeActions || (action == .disconnect && agent == .claude) { onActionsConsent(false) }
        let targetName = action.scope == .claudeQuota ? "quota forwarding" : (action.scope == .claudeActions ? "interactive hooks" : "lifecycle hooks")
        message = action.isCheck ? "Checking \(providerName) \(targetName)…" : "Updating owned \(providerName) \(targetName)…"
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.generation == current {
                    self.operation = nil
                    self.task = nil
                }
            }
            var disconnectedScopes: [String] = []
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
                    else if action.scope == .claudeQuota { self.quotaInspection = nil }
                    else { self.actionInspection = nil }
                    if action == .disconnect, self.agent == .claude {
                        self.actionInspection = nil
                        let actionContext = try self.context(needsExecutable: false, scope: .claudeActions)
                        let removedActions = try await self.service.executeAndInspect(.remove, context: actionContext)
                        disconnectedScopes.append("local responses")
                        try Task.checkCancellation()
                        self.actionInspection = removedActions.inspection
                        try Task.checkCancellation()
                        self.quotaInspection = nil
                        let quotaContext = try self.context(needsExecutable: false, scope: .claudeQuota)
                        let removedQuota = try await self.service.executeAndInspect(.remove, context: quotaContext)
                        disconnectedScopes.append("quota forwarding")
                        try Task.checkCancellation()
                        self.quotaInspection = removedQuota.inspection
                        try Task.checkCancellation()
                    }
                    let result = try await self.service.executeAndInspect(removing ? .remove : .connect, context: context) { [weak self] stage in
                        await self?.showProgress(stage, generation: current)
                    }
                    try Task.checkCancellation()
                    guard self.generation == current else { return }
                    if action == .connectActions { self.onActionsConsent(true) }
                    if !removing { self.onConnected() }
                    switch result.change {
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
                    self.record(result.inspection, scope: action.scope)
                    if action.scope == .lifecycle { self.onInspection(result.inspection.health) }
                }
            } catch is CancellationError {
                if self.generation == current {
                    self.message = "Stopped observing this operation. If saving had begun, use Check before retrying."
                    if !disconnectedScopes.isEmpty { self.message += " Removal completed for: " + disconnectedScopes.joined(separator: ", ") + ". This provider remains paused." }
                }
            } catch let failure as ProviderSetupFailure {
                if self.generation == current {
                    self.message = Self.explanation(failure, agent: self.agent)
                    if !disconnectedScopes.isEmpty { self.message += " Removal completed for: " + disconnectedScopes.joined(separator: ", ") + ". This provider remains paused. Use Check before retrying." }
                }
            } catch {
                if self.generation == current {
                    self.message = "Setup could not finish. Use Check before retrying; no automatic recovery over uncertain changes is attempted."
                    if !disconnectedScopes.isEmpty { self.message += " Removal completed for: " + disconnectedScopes.joined(separator: ", ") + ". This provider remains paused." }
                }
            }
        }
    }

    private func showProgress(_ stage: ProviderSetupStage, generation: UUID) {
        guard self.generation == generation else { return }
        switch stage {
        case .checking: message = "Checking \(providerName) version and hook policy…"
        case .saving: message = "Saving owned \(providerName) hooks…"
        case .verifying: message = "Verifying saved \(providerName) hooks…"
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
        else if scope == .claudeQuota { quotaInspection = result }
        else { actionInspection = result }
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
            helperURL: executableDirectory.appendingPathComponent(scope == .lifecycle ? "NotchPetHook" : (scope == .claudeQuota ? "NotchPetStatusLine" : "NotchPetActionHook")),
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
        case .executableNotFound:
            return "Couldn't find \(name). Bunlet looked in your PATH, ~/.local/bin, Homebrew and nvm. Configuration was not changed."
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
