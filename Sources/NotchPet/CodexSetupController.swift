import CryptoKit
import Darwin
import EventBridge
import Foundation
import Integration
import Observation

enum CodexSetupAction: Equatable {
    case connect, check, remove
}

/// View-owned action state, separate from configuration, delivery and live session truth.
@MainActor
@Observable
final class CodexSetupController {
    private(set) var operation: CodexSetupAction?
    private(set) var inspection: CodexSetupInspection?
    private(set) var confirmation: CodexSetupAction?
    private(set) var message = "Check Codex to inspect setup. Connecting is optional."
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let service: CodexSetupService
    @ObservationIgnored private let onConnected: () -> Void
    @ObservationIgnored private let onInspection: (IntegrationHealthEvidence) -> Void

    init(service: CodexSetupService = CodexSetupService(), onConnected: @escaping () -> Void,
         onInspection: @escaping (IntegrationHealthEvidence) -> Void) {
        self.service = service
        self.onConnected = onConnected
        self.onInspection = onInspection
    }

    func start(_ action: CodexSetupAction) {
        guard task == nil else { return }
        let current = UUID()
        generation = current
        operation = action
        message = action == .check ? "Checking Codex…" : "Updating owned Codex hooks…"
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.generation == current {
                    self.operation = nil
                    self.task = nil
                }
            }
            do {
                let context = try self.context(needsExecutable: action != .remove)
                ServiceStartLedger.record(.configurationProbe)
                if action == .check {
                    let result = await self.service.check(context)
                    try Task.checkCancellation()
                    guard self.generation == current else { return }
                    self.inspection = result
                    self.onInspection(result.health)
                    self.message = Self.summary(result)
                } else {
                    self.inspection = nil
                    let change = try await self.service.execute(action == .connect ? .connect : .remove, context: context)
                    try Task.checkCancellation()
                    guard self.generation == current else { return }
                    if action == .connect { self.onConnected() }
                    switch change {
                    case .installed:
                        self.message = "Owned hooks installed. Complete Codex’s normal hook trust review; session delivery is not yet confirmed."
                    case .removed:
                        self.message = "Owned hooks removed. Monitoring and retained requests keep their own state."
                    case .unchanged:
                        self.message = action == .connect ? "Owned hooks are unchanged. Session delivery is separate from installation."
                            : "No owned hooks needed removal."
                    }
                    let result = await self.service.check(context)
                    try Task.checkCancellation()
                    guard self.generation == current else { return }
                    self.inspection = result
                    self.onInspection(result.health)
                }
            } catch is CancellationError {
                if self.generation == current {
                    self.message = "Stopped observing this operation. If saving had begun, use Check before retrying."
                }
            } catch let failure as CodexSetupFailure {
                if self.generation == current { self.message = Self.explanation(failure) }
            } catch {
                if self.generation == current {
                    self.message = "Setup could not finish. Use Check before retrying; no automatic recovery over uncertain changes is attempted."
                }
            }
        }
    }

    func requestConfirmation(_ action: CodexSetupAction) {
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

    private func context(needsExecutable: Bool) throws -> CodexSetupContext {
        let manager = FileManager.default
        let override = try environmentValue("CODEX_HOME", limit: 4096)
        let executable: URL?
        if needsExecutable {
            let searchPath = try environmentValue("PATH", limit: 16_384)
            switch AgentPathLocator.executable(agent: .codex, policy: .health, searchPath: searchPath,
                                              homeDirectory: manager.homeDirectoryForCurrentUser) {
            case .found(let url): executable = url
            case .notFound, .invalidSearchPath: executable = nil
            }
        } else {
            executable = nil
        }
        guard let directory = AgentPathLocator.configurationDirectory(agent: .codex, override: override,
                  homeDirectory: manager.homeDirectoryForCurrentUser),
              let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent(),
              let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CodexSetupFailure.unsafePath
        }
        let identity = SHA256.hash(data: Data(directory.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return CodexSetupContext(configurationDirectory: directory,
            ownershipDirectory: support.appendingPathComponent("NotchPet/Integrations/Codex").appendingPathComponent(identity),
            helperURL: executableDirectory.appendingPathComponent("NotchPetHook"), executableURL: executable)
    }

    private func environmentValue(_ key: String, limit: Int) throws -> String? {
        guard let value = getenv(key) else { return nil }
        guard strnlen(value, limit + 1) <= limit else { throw CodexSetupFailure.resourceLimit }
        return String(cString: value)
    }

    private static func summary(_ inspection: CodexSetupInspection) -> String {
        switch inspection.ownership {
        case .recoveryRequired:
            return "A saved operation needs recovery. Finish other configuration edits, then explicitly retry Connect or Remove hooks. Conflicting states require manual reconciliation."
        case .conflict:
            return "Hook ownership or configuration conflicts with the saved record. Leave the files in place for manual reconciliation."
        case .owned:
            return "Owned hooks match. Trust, receiver readiness and actual delivery remain separate evidence."
        case .notOwned:
            return inspection.installationUnavailable.map(explanation) ?? "No owned hooks. Connect can install this app’s entries."
        }
    }

    static func explanation(_ failure: CodexSetupFailure) -> String {
        switch failure {
        case .unqualifiedVersion:
            return "This Codex version has not been qualified for automatic setup."
        case .enablementUnverified:
            return "Effective Codex hook policy could not be verified. Configuration was not changed."
        case .hooksDisabled:
            return "Codex hooks are disabled. Review Codex’s settings before connecting."
        case .managedHooksOnly:
            return "Codex policy allows managed hooks only. Contact your administrator about user hooks."
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
