import Darwin
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

    init(store: UsageStore, sessions: SessionStore) {
        self.store = store
        self.sessions = sessions
    }

    func start() {
        guard observation == nil else { return }
        observation = ObservationLoop({ [sessions] in
            NotchPresentation.activeProviders(sessions.sessions).contains(.codex)
        }) { [weak self] active in
            self?.setCodexActive(active)
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
        task?.cancel()
        task = nil
    }

    private func setCodexActive(_ active: Bool) {
        task?.cancel()
        task = nil
        guard active else { return }
        ServiceStartLedger.record(.agentRefresh)
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let path = getenv("PATH").map { String(cString: $0) }
            let executable: URL
            switch AgentPathLocator.executable(agent: .codex, policy: .usage, searchPath: path,
                                              homeDirectory: FileManager.default.homeDirectoryForCurrentUser) {
            case .found(let url):
                executable = url
            case .notFound:
                self.status = "Codex executable unavailable."
                return
            case .invalidSearchPath:
                self.status = "Executable search path unavailable."
                return
            }
            while !Task.isCancelled {
                ServiceStartLedger.record(.providerProcess)
                let observation = await CodexUsageConnection.read(executableURL: executable,
                                                                 sourceID: "codex-managed")
                guard !Task.isCancelled else { return }
                self.store.apply(observation)
                do { try await Task.sleep(for: .seconds(120)) }
                catch { return }
            }
        }
    }
}
