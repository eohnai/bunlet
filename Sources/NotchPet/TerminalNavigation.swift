import AppKit
import Combine
import Foundation
import Observation
import SessionState
import UniformTypeIdentifiers

private struct TerminalApplicationChoice: Codable {
    let version: Int
    let identifier: String
    let path: String
    let name: String

    var valid: Bool {
        version == 1 && !identifier.isEmpty && identifier.utf8.count <= 256 && path.hasPrefix("/") &&
            path.utf8.count <= 4096 && !name.isEmpty && name.utf8.count <= 128 &&
            ![identifier, path, name].contains(where: { value in
                value.unicodeScalars.contains { $0.properties.generalCategory == .control }
            })
    }
}

struct TerminalPaneIdentity: Sendable {
    let id: String
    let tty: String
}

/// A capability interface: core session monitoring does not know or require a terminal vendor.
protocol TerminalPaneAdapter: Sendable {
    var applicationIdentifier: String { get }
    func currentPane(processID: pid_t) async -> TerminalPaneIdentity?
    func focus(_ pane: TerminalPaneIdentity, processID: pid_t) async -> Bool
}

@MainActor
@Observable
final class TerminalNavigation {
    private struct Binding {
        let adapterID: String
        let processID: pid_t
        let launchedAt: Date
        let pane: TerminalPaneIdentity
    }
    private(set) var message = "Choose a terminal application, or return to the existing session manually."
    private(set) var busy = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sessions: SessionStore
    @ObservationIgnored private let adapters: [any TerminalPaneAdapter] = [ITermPaneAdapter()]
    private var preferred: TerminalApplicationChoice?
    private var bindings: [SessionKey: Binding] = [:]
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var chooser: NSOpenPanel?
    @ObservationIgnored private var observation: ObservationLoop<[SessionSnapshot]>?
    @ObservationIgnored private var subscriptions: Set<AnyCancellable> = []
    @ObservationIgnored private var operationKey: SessionKey?
    @ObservationIgnored private var generation = UUID()
    private static let preferenceKey = "navigation.application.v1"

    init(defaults: UserDefaults, sessions: SessionStore) {
        self.defaults = defaults
        self.sessions = sessions
        if let data = defaults.data(forKey: Self.preferenceKey), data.count <= 8192,
           let choice = try? JSONDecoder().decode(TerminalApplicationChoice.self, from: data), choice.valid {
            preferred = choice
        }
    }

    var preferredName: String? { preferred?.name }
    var canLinkPreferredPane: Bool { adapters.contains { $0.applicationIdentifier == preferred?.identifier } }
    func hasLinkedPane(_ key: SessionKey) -> Bool { bindings[key] != nil }

    func start() {
        guard observation == nil else { return }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                MainActor.assumeIsolated { self?.cancel() }
            }.store(in: &subscriptions)
        observation = ObservationLoop({ [sessions] in sessions.sessions }) { [weak self] snapshots in
            let current = Set(snapshots.filter { !$0.hasTerminalRestriction && $0.status != .ended }.map(\.key))
            guard let self else { return }
            self.bindings = self.bindings.filter { current.contains($0.key) }
            if let key = self.operationKey, !current.contains(key) { self.task?.cancel() }
        }
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        chooser?.cancel(nil)
        chooser = nil
        busy = false
        observation?.cancel()
        observation = nil
        subscriptions.removeAll()
        bindings = [:]
        operationKey = nil
    }

    func chooseApplication() {
        guard !busy else { return }
        busy = true
        let panel = NSOpenPanel()
        chooser = panel
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose your terminal application. Activation will only use an already-running instance."
        panel.begin { [weak self, weak panel] response in
            MainActor.assumeIsolated {
                guard let self else { return }
                let url = panel?.url?.resolvingSymlinksInPath().standardizedFileURL
                self.chooser = nil
                self.busy = false
                guard response == .OK, let url, let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return }
                let choice = TerminalApplicationChoice(version: 1, identifier: identifier, path: url.path,
                    name: url.deletingPathExtension().lastPathComponent)
                guard choice.valid, let data = try? JSONEncoder().encode(choice), data.count <= 8192 else {
                    self.message = "This application identity is unavailable. Return manually."
                    return
                }
                self.defaults.set(data, forKey: Self.preferenceKey)
                guard self.defaults.data(forKey: Self.preferenceKey) == data else {
                    self.message = "The application choice could not be saved."
                    return
                }
                self.preferred = choice
                self.message = "Application selected. Activating it does not choose an agent session or pane."
            }
        }
    }

    func activateApplication() {
        guard !busy, let app = preferredApplication() else {
            message = "Start your chosen terminal yourself, or choose an application. No replacement window is opened."
            return
        }
        message = app.activate(options: []) ? "Application activation requested. Select your existing session manually." : "Application activation was unavailable. Return manually."
    }

    func linkCurrentPane(to key: SessionKey) {
        guard !busy, current(key), bindings[key] != nil || bindings.count < SessionStore.sessionLimit,
              let choice = preferred, let adapter = adapters.first(where: { $0.applicationIdentifier == choice.identifier }),
              let app = preferredApplication(), let launch = app.launchDate else {
            message = "Exact-pane linking is unavailable. Choose a supported running application, or use application activation/manual return."
            return
        }
        let pid = app.processIdentifier
        run(for: key) { [weak self] in
            let pane = await adapter.currentPane(processID: pid)
            guard let self, !Task.isCancelled, self.current(key), let pane,
                  self.sameApplication(adapter.applicationIdentifier, pid: pid, launch: launch) != nil else { return false }
            if self.bindings.contains(where: { other, binding in
                other != key && binding.adapterID == adapter.applicationIdentifier && binding.processID == pid &&
                    binding.launchedAt == launch && binding.pane.id.utf8.elementsEqual(pane.id.utf8) &&
                    binding.pane.tty.utf8.elementsEqual(pane.tty.utf8)
            }) {
                self.message = "This pane is already linked to another observed session. Unlink that association first."
                return true
            }
            self.bindings[key] = Binding(adapterID: adapter.applicationIdentifier, processID: pid, launchedAt: launch, pane: pane)
            self.message = "Current pane linked by you. Agent-to-pane mapping is not automatically verified."
            return true
        }
    }

    func focusLinkedPane(for key: SessionKey) {
        guard !busy, current(key), let binding = bindings[key],
              let adapter = adapters.first(where: { $0.applicationIdentifier == binding.adapterID }),
              sameApplication(binding.adapterID, pid: binding.processID, launch: binding.launchedAt) != nil else {
            bindings.removeValue(forKey: key)
            message = "The linked terminal instance is unavailable. Link again or return manually."
            return
        }
        run(for: key) { [weak self] in
            guard await adapter.focus(binding.pane, processID: binding.processID), let self, !Task.isCancelled, self.current(key),
                  let app = self.sameApplication(binding.adapterID, pid: binding.processID, launch: binding.launchedAt) else { return false }
            self.message = app.activate(options: []) ? "Linked pane focus confirmed by the terminal. Agent state is unchanged." : "Pane selected; application activation is unconfirmed. Return manually."
            return true
        }
    }

    func unlink(_ key: SessionKey) { bindings.removeValue(forKey: key) }

    func cancel() {
        chooser?.cancel(nil)
        task?.cancel()
    }

    private func current(_ key: SessionKey) -> Bool {
        sessions.sessions.contains { $0.key == key && !$0.hasTerminalRestriction && $0.status != .ended }
    }

    private func preferredApplication() -> NSRunningApplication? {
        guard let choice = preferred else { return nil }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: choice.identifier).filter { !$0.isTerminated }
        guard apps.count == 1, let app = apps.first,
              app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path == choice.path else { return nil }
        return app
    }

    private func sameApplication(_ identifier: String, pid: pid_t, launch: Date) -> NSRunningApplication? {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).filter { !$0.isTerminated }
        guard apps.count == 1, let app = apps.first, app.processIdentifier == pid, app.launchDate == launch else { return nil }
        return app
    }

    private func run(for key: SessionKey, _ action: @escaping @MainActor () async -> Bool) {
        let token = UUID()
        generation = token
        operationKey = key
        busy = true
        message = "Checking terminal navigation. Complete normal macOS Automation review if requested."
        task = Task { @MainActor [weak self] in
            let success = await action()
            guard let self, self.generation == token else { return }
            self.busy = false
            self.task = nil
            self.operationKey = nil
            if Task.isCancelled || !success {
                self.message = "Navigation was cancelled, unavailable or uncertain. No automatic retry. Return manually or link again."
            }
        }
    }
}

extension TerminalNavigation {
    /// Returns to a session's terminal: its linked pane, else the preferred app.
    /// Returns false when neither is set up, so the caller can show terminal setup instead.
    @discardableResult
    func jump(to key: SessionKey) -> Bool {
        if hasLinkedPane(key) {
            focusLinkedPane(for: key)
        } else if preferredName != nil {
            activateApplication()
        } else {
            return false
        }
        return true
    }
}
