import Foundation

/// Session states (spec: timer-engine "Session state machine").
public enum SessionState: String, Sendable, Equatable, Codable {
    case idle, running, held, onBreak = "break", closed
}

/// User intents. Transitions happen only through these or policy expiry.
public enum SessionIntent: String, Sendable, Equatable, Codable {
    case begin, hold, resume, startBreak, endBreak, close
}

public enum SessionError: Error, Equatable, Sendable {
    case invalidTransition(intent: SessionIntent, from: SessionState)
}

/// One recorded transition. Canonical wall-clock timestamps are the only
/// source of truth for time arithmetic; ticks are presentation-only.
public struct TransitionRecord: Equatable, Sendable, Codable {
    public let intent: SessionIntent?
    public let state: SessionState
    public let at: Date

    public init(intent: SessionIntent?, state: SessionState, at: Date) {
        self.intent = intent
        self.state = state
        self.at = at
    }
}

/// The deterministic session value. Pure Foundation; UI-free and edition-free.
public struct Session: Equatable, Sendable, Codable {
    public let policy: TimingPolicy
    public internal(set) var transitions: [TransitionRecord]
    var anomalyLog: [ClockAnomaly] = []

    public init(policy: TimingPolicy, startedAt: Date?) {
        self.policy = policy
        self.transitions = [TransitionRecord(intent: nil, state: .idle, at: startedAt ?? .distantPast)]
    }

    /// Rebuild from persisted transitions (spec: relaunch recovery).
    public init(policy: TimingPolicy, transitions: [TransitionRecord]) {
        self.policy = policy
        self.transitions =
            transitions.isEmpty
            ? [TransitionRecord(intent: nil, state: .idle, at: .distantPast)]
            : transitions
    }

    public func state(at now: Date) -> SessionState {
        transitions.last?.state ?? .idle
    }

    private static let table: [SessionIntent: [SessionState: SessionState]] = [
        .begin: [.idle: .running],
        .hold: [.running: .held],
        .resume: [.held: .running],
        .startBreak: [.running: .onBreak, .held: .onBreak],
        .endBreak: [.onBreak: .running],
        .close: [.running: .closed, .held: .closed, .onBreak: .closed],
    ]

    public mutating func apply(_ intent: SessionIntent, at now: Date) throws {
        let current = transitions.last?.state ?? .idle
        guard let next = Self.table[intent]?[current] else {
            throw SessionError.invalidTransition(intent: intent, from: current)
        }
        transitions.append(TransitionRecord(intent: intent, state: next, at: now))
    }
}
