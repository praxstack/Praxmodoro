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
    let capabilities: CapabilityRegistry
    private let clock: () -> Date

    init(store: LocalStore?, capabilities: CapabilityRegistry = CapabilityRegistry(edition: .lite), clock: @escaping () -> Date = { Date() }) {
        self.store = store
        self.capabilities = capabilities
        self.clock = clock
        // Spec: startup validation fails fast in debug; lookup self-heals in release.
        do { try capabilities.validate() } catch { assertionFailure("capability validation failed: \(error)") }
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
        try store?.saveTask(sessionID: id, title: taskTitle, firstAction: firstAction, at: now)
        try store?.appendEvent(sessionID: id, kind: .transition, payload: "running", at: now)
        if !capacity.isEmpty {
            try store?.appendEvent(sessionID: id, kind: .capacityReport, payload: capacity, at: now)
        }
    }

    /// Relaunch lands the user exactly where they were: rebuild the session
    /// purely from persisted transitions (spec: app-scaffold lifecycle).
    func restore() throws {
        guard let store, let summary = try store.latestSession() else { return }
        let events = try store.events(sessionID: summary.id)
        let transitions = events
            .filter { $0.kind == .transition }
            .map { TransitionRecord(intent: nil, state: SessionState(rawValue: $0.payload) ?? .running, at: $0.at) }
        guard let last = transitions.last, last.state != .closed else { return }

        let records = [TransitionRecord(intent: nil, state: .idle, at: summary.startedAt)] + transitions
        session = Session(policy: TimingPolicy.named(summary.policyName), transitions: records)
        sessionID = summary.id
        policy = TimingPolicy.named(summary.policyName)
        if let task = try store.task(sessionID: summary.id) {
            taskTitle = task.title
            firstAction = task.firstAction
        }
        parkedThoughts = events.filter { $0.kind == .thoughtParked }.map(\.payload)

        let now = clock()
        switch session?.reconciled(at: now).state(at: now) {
        case .running, .held: surface = .focus
        case .onBreak: surface = .onBreak
        default: surface = .initiate
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

    // MARK: Break (spec: user-steerable, held place, ending early is ordinary)

    /// Suggestion derived only from what the user reported — never from a
    /// claim about what is optimal. Pure over reported inputs, so early break
    /// ends can never alter future suggestion weight.
    var breakSuggestion: String {
        switch capacity {
        case "restless": "Stretch — unclench the jaw, drop the shoulders."
        case "foggy": "Water — stand, pour, sip slowly."
        case "charged": "Step away — a doorway or a window counts."
        default: "Quiet — no prompt, just the held place."
        }
    }

    var breakSuggestionProvenance: String {
        "You said “\(capacity)”, so this suggestion came first. This pattern is editable and can be turned off entirely."
    }

    /// The re-entry card: the exact next action, waiting for the return.
    var reentryStep: String { firstAction }

    func chooseBreak(_ choice: String) throws {
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .breakChoice, payload: choice, at: clock())
        }
    }

    /// Ending a break — at any moment — is ordinary: resume and return to
    /// focus with no notice, penalty, or record beyond the transition itself.
    func endBreak() throws {
        guard var current = session else { return }
        let now = clock()
        try current.apply(.endBreak, at: now)
        session = current
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .transition, payload: "running", at: now)
        }
        surface = .focus
    }

    // MARK: Review (spec: a record, not a verdict)

    struct TimelineEntry: Equatable {
        let at: Date
        let label: String
    }

    func closeSession() throws {
        guard var current = session else { return }
        let now = clock()
        try current.apply(.close, at: now)
        session = current
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .transition, payload: "closed", at: now)
        }
        surface = .review
    }

    /// Descriptive timeline straight from the event log — what happened,
    /// never how well.
    func reviewTimeline() throws -> [TimelineEntry] {
        guard let id = sessionID, let store else { return [] }
        return try store.events(sessionID: id).map { event in
            let label: String
            switch event.kind {
            case .transition:
                label = switch event.payload {
                case "running": "Focus resumed"
                case "held": "Held — place kept"
                case "break": "Chose an intentional break"
                case "closed": "Closed the session"
                default: "State: \(event.payload)"
                }
            case .checkinAnswer:
                label = "Check-in: \(CheckinAnswer(rawValue: event.payload)?.label ?? event.payload)"
            case .thoughtParked: label = "Parked a thought"
            case .breakChoice: label = "Break: \(event.payload)"
            case .capacityReport: label = "Reported capacity: \(event.payload)"
            case .edit: label = "Edited a note"
            case .clockAnomaly: label = "Clock changed — time kept honest"
            }
            return TimelineEntry(at: event.at, label: label)
        }
    }

    /// Uncertainty-aware, non-diagnostic insight. Single-session data always
    /// states its limits (spec: "Single-day observations stay tentative").
    var reviewInsight: String {
        let resized = (try? reviewTimeline())?.contains { $0.label.contains("smaller") } ?? false
        let base = resized
            ? "Making the step smaller kept things moving today."
            : "You stayed with the loop today."
        return base + " One session is not a pattern — the options simply stay offered."
    }

    // MARK: Accessibility (spec: VoiceOver reads a concise field summary)

    func fieldAccessibilitySummary(at now: Date) -> String {
        guard let session else { return "Companion: resting" }
        let state = session.reconciled(at: now).state(at: now)
        if state == .held { return "Companion: holding your place" }
        guard let remaining = remaining(at: now) else { return "Companion: breathing, open-ended block" }
        let minutes = Int((remaining / 60).rounded())
        return "Companion: breathing, \(minutes) minute\(minutes == 1 ? "" : "s") remaining"
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
