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
    /// All sessions, and the keys of those the island lists. Both are observed so removing a row updates the mood.
    private struct Observed: Equatable, Sendable {
        let all: [SessionSnapshot]
        let listed: Set<SessionKey>
    }
    private let sessions: SessionStore
    private let listed: @MainActor ([SessionSnapshot]) -> [SessionSnapshot]
    private let onChange: (PetMood, Bool) -> Void
    private var observation: ObservationLoop<Observed>?
    private var previous: [SessionKey: SessionSnapshot] = [:]
    private var seen: Set<ReadyIdentity> = []
    private let cueCapacity = 4096
    private(set) var mood: PetMood = .idle

    /// `listed` applies the island's listing rules, so the bubble describes the sessions the panels show.
    init(sessions: SessionStore, listed: @escaping @MainActor ([SessionSnapshot]) -> [SessionSnapshot] = { $0 },
         onChange: @escaping (PetMood, Bool) -> Void) {
        self.sessions = sessions
        self.listed = listed
        self.onChange = onChange
    }

    func start() {
        guard observation == nil else { return }
        // Existing ready records establish a baseline without replaying a completed response.
        previous = Dictionary(uniqueKeysWithValues: sessions.sessions.map { ($0.key, $0) })
        observation = ObservationLoop({ [sessions, listed] in
            let all = sessions.sessions
            return Observed(all: all, listed: Set(listed(all).map(\.key)))
        }) { [weak self] in self?.update($0) }
    }

    func stop() {
        observation?.cancel()
        observation = nil
        previous = [:]
    }

    private func update(_ observed: Observed) {
        let snapshots = observed.all
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
        mood = Self.mood(all: snapshots, listed: snapshots.filter { observed.listed.contains($0.key) })
        onChange(mood, cue && mood == .responseReady)
    }

    /// Listed sessions decide the mood. Ended sessions are never listed (decision 0032), so Ended still
    /// looks at every session: it shows once all of them have ended.
    static func mood(all: [SessionSnapshot], listed: [SessionSnapshot]) -> PetMood {
        if listed.contains(where: { $0.status == .approvalNeeded || $0.status == .questionNeeded }) { return .attention }
        if listed.contains(where: { $0.status == .working }) { return .working }
        // A failed turn outranks a successful one, so the error is not hidden behind "Response ready".
        if listed.contains(where: { $0.status == .responseReady && $0.turnFailed }) { return .failed }
        if listed.contains(where: { $0.status == .responseReady }) { return .responseReady }
        if listed.isEmpty && !all.isEmpty && all.allSatisfy({ $0.status == .ended }) { return .ended }
        return .idle
    }
}
