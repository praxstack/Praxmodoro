import Foundation
import Observation
import PraxmodoroCore
import PraxmodoroStore

enum Surface: Equatable {
    case initiate, focus, checkin, onBreak, review
}

/// App-level state: routes surfaces, drives the engine with the injected
/// clock, and records every event locally. UI reads; the engine decides.
@MainActor
@Observable
final class AppModel {
    var surface: Surface = .initiate
    var taskTitle = ""
    var firstAction = ""
    var capacity = "steady"
    var policy: TimingPolicy = .gentleStart

    private(set) var session: Session?
    private(set) var sessionID: UUID?
    private(set) var parkedThoughts: [String] = []

    let store: LocalStore?
    private let clock: () -> Date

    init(store: LocalStore?, clock: @escaping () -> Date = { Date() }) {
        self.store = store
        self.clock = clock
    }

    func begin() throws {
        let now = clock()
        var newSession = Session(policy: policy, startedAt: now)
        try newSession.apply(.begin, at: now)
        session = newSession
        let id = UUID()
        sessionID = id
        surface = .focus
        try store?.createSession(id: id, policyName: policy.name, startedAt: now)
        try store?.appendEvent(sessionID: id, kind: .transition, payload: "running", at: now)
        if !capacity.isEmpty {
            try store?.appendEvent(sessionID: id, kind: .capacityReport, payload: capacity, at: now)
        }
    }

    /// Capture without changing context (spec: thought parking).
    func parkThought(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        parkedThoughts.append(trimmed)
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .thoughtParked, payload: trimmed, at: clock())
        }
        // Surface intentionally untouched — focus stays active.
    }

    func toggleHold() throws {
        guard var current = session else { return }
        let now = clock()
        let state = current.reconciled(at: now).state(at: now)
        let intent: SessionIntent = state == .held ? .resume : .hold
        try current.apply(intent, at: now)
        session = current
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .transition, payload: current.state(at: now).rawValue, at: now)
        }
    }

    // MARK: Check-in (spec: no failure state; never interrupts destructively)

    private(set) var checkinPending = false
    private(set) var isEditingThought = false
    private(set) var lastCheckinResponse: String?

    /// Open the check-in: the timer holds while the question is open.
    func openCheckin() throws {
        if !isHeld { try toggleHold() }
        surface = .checkin
    }

    /// A due check-in defers while the user is mid-keystroke in thought
    /// parking; it presents when the field loses focus.
    func checkinBecameDue() throws {
        if isEditingThought {
            checkinPending = true
        } else {
            try openCheckin()
        }
    }

    func thoughtEditingBegan() { isEditingThought = true }

    func thoughtEditingEnded() throws {
        isEditingThought = false
        if checkinPending {
            checkinPending = false
            try openCheckin()
        }
    }

    func answer(_ answer: CheckinAnswer) throws {
        lastCheckinResponse = answer.response
        let now = clock()
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .checkinAnswer, payload: answer.rawValue, at: now)
        }
        switch answer {
        case .stillFits, .smallerStep, .drifted:
            if isHeld { try toggleHold() }
            surface = .focus
        case .needBreak:
            guard var current = session else { return }
            try current.apply(.startBreak, at: now)
            session = current
            if let id = sessionID {
                try store?.appendEvent(sessionID: id, kind: .transition, payload: "break", at: now)
            }
            surface = .onBreak
        }
    }

    var isHeld: Bool {
        guard let session else { return false }
        let now = clock()
        return session.reconciled(at: now).state(at: now) == .held
    }

    /// Remaining time is derived through the engine — the view never counts.
    func remaining(at now: Date) -> TimeInterval? {
        session?.reconciled(at: now).remaining(at: now)
    }
}
