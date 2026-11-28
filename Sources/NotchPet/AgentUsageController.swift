import AppKit
import Darwin
import EventBridge
import Foundation
import Integration
import Observation
import SessionState
import Usage

/// Optional app-owned usage I/O; SwiftUI only observes the resulting status/store.
@MainActor
@Observable
final class AgentUsageController: AppFeatureService {
    private(set) var status = "Reading usage limits…"
    private let store: UsageStore
    private let sessions: SessionStore
    private var observation: ObservationLoop<Bool>?
    private var task: Task<Void, Never>?
    private var enabledProviders = Set(Agent.allCases)
    private var codexActive = false
    /// Tests replace the Codex App Server read. Nil reads through the installed Codex executable.
    private let readOverride: (@MainActor () async -> UsageObservation)?

    init(store: UsageStore, sessions: SessionStore, read: (@MainActor () async -> UsageObservation)? = nil) {
        self.store = store
        self.sessions = sessions
        self.readOverride = read
    }

    func start() {
        guard observation == nil else { return }
        observation = ObservationLoop({ [sessions, weak self] in
            self?.enabledProviders.contains(.codex) == true &&
                NotchPresentation.activeProviders(sessions.sessions).contains(.codex)
        }) { [weak self] active in
            self?.setCodexActive(active)
        }
        // One read at start, so the Codex badge shows before a session reports anything. A session that is already
        // open and quiet sends no event after Bunlet starts. Reading again every 120 seconds still needs an active session.
        if !codexActive, enabledProviders.contains(.codex) {
            ServiceStartLedger.record(.agentRefresh)
            task = readCodex(repeating: false)
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
        task?.cancel()
        task = nil
        codexActive = false
    }

    func setEnabledProviders(_ providers: Set<Agent>) {
        enabledProviders = providers
        guard !providers.contains(.codex) else { return }
        setCodexActive(false)
        // The start read runs while Codex is not active, so turning Codex off must cancel it separately.
        task?.cancel()
        task = nil
    }

    private func setCodexActive(_ active: Bool) {
        guard codexActive != active else { return }
        codexActive = active
        task?.cancel()
        task = nil
        guard active else { return }
        ServiceStartLedger.record(.agentRefresh)
        task = readCodex(repeating: true)
    }

    /// Reads Codex limits once, or repeatedly while Codex stays active. Only one read task exists at a time, so reads
    /// never overlap: becoming active cancels the start read.
    private func readCodex(repeating: Bool) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let read: @MainActor () async -> UsageObservation
            if let readOverride = self.readOverride {
                read = readOverride
            } else {
                guard let executable = self.codexExecutable() else { return }
                read = { await CodexUsageConnection.read(executableURL: executable, sourceID: "codex-managed") }
            }
            var failures = 0
            let delays = [5, 15, 30, 60, 120]
            while !Task.isCancelled {
                ServiceStartLedger.record(.providerProcess)
                let observation = await read()
                guard !Task.isCancelled else { return }
                self.store.apply(observation)
                let delay: Int
                if observation.failure == nil {
                    failures = 0
                    delay = 120
                    self.status = "Codex usage received; measurement time unverified."
                } else {
                    delay = delays[min(failures, delays.count - 1)]
                    failures = min(failures + 1, delays.count)
                    self.status = repeating ? "Codex usage unavailable. Retrying in \(delay) seconds."
                        : "Codex usage unavailable. Bunlet reads again when a Codex session starts."
                }
                guard repeating else { return }
                do { try await Task.sleep(for: .seconds(delay)) }
                catch { return }
            }
        }
    }

    private func codexExecutable() -> URL? {
        let path = getenv("PATH").map { String(cString: $0) }
        switch AgentPathLocator.executable(agent: .codex, policy: .usage, searchPath: path,
                                          homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
                                          desktopApplication: NSWorkspace.shared.urlForApplication(withBundleIdentifier:)) {
        case .found(let url):
            return url
        case .notFound:
            status = "Codex executable unavailable."
            return nil
        case .invalidSearchPath:
            status = "Executable search path unavailable."
            return nil
        }
    }
}
