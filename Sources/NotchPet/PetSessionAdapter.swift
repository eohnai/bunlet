import Foundation
import Pet
import SessionState

/// Shares observation authority with Notch; never writes lifecycle state or provider actions.
@MainActor
final class PetSessionAdapter {
    private struct ReadyIdentity: Hashable {
        let session: SessionKey
        let turn: Data
        let stop: Int64
    }
    private let sessions: SessionStore
    private let onChange: (PetMood, Bool) -> Void
    private var observation: ObservationLoop<[SessionSnapshot]>?
    private var previous: [SessionKey: SessionSnapshot] = [:]
    private var seen: Set<ReadyIdentity> = []
    private let cueCapacity = 4096
    private(set) var mood: PetMood = .idle

    init(sessions: SessionStore, onChange: @escaping (PetMood, Bool) -> Void) {
        self.sessions = sessions
        self.onChange = onChange
    }

    func start() {
        guard observation == nil else { return }
        // Existing ready records establish a baseline without replaying a completed response.
        previous = Dictionary(uniqueKeysWithValues: sessions.sessions.map { ($0.key, $0) })
        observation = ObservationLoop({ [sessions] in sessions.sessions }) { [weak self] in self?.update($0) }
    }

    func stop() {
        observation?.cancel()
        observation = nil
        previous = [:]
    }

    private func update(_ snapshots: [SessionSnapshot]) {
        var cue = false
        for session in snapshots where session.status == .responseReady {
            guard let turn = session.currentTurnID, let stop = session.responseReadyAtMs else { continue }
            let identity = ReadyIdentity(session: session.key, turn: Data(turn.utf8), stop: stop)
            guard !seen.contains(identity), seen.count < cueCapacity else { continue }
            seen.insert(identity)
            let before = previous[session.key]
            let alreadyReady = before?.status == .responseReady && before?.responseReadyAtMs == stop &&
                before?.currentTurnID?.utf8.elementsEqual(turn.utf8) == true
            if !alreadyReady && session.turnStartedAtMs != nil { cue = true }
        }
        previous = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.key, $0) })
        if snapshots.contains(where: { $0.pendingRequests.contains(where: \.isConfirmed) }) {
            mood = .attention
        } else if snapshots.contains(where: { $0.status == .unknown || !$0.pendingRequests.isEmpty }) {
            mood = .unknown
        } else if snapshots.contains(where: { $0.status == .working }) {
            mood = .working
        } else if snapshots.contains(where: { $0.status == .responseReady }) {
            mood = .responseReady
        } else if !snapshots.isEmpty && snapshots.allSatisfy({ $0.status == .ended }) {
            mood = .ended
        } else { mood = .idle }
        onChange(mood, cue && mood == .responseReady)
    }
}
