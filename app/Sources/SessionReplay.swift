import Foundation
import PraxmodoroCore
import PraxmodoroStore

enum TransitionPayload {
    private static let running = "running"
    private static let held = "held"
    private static let onBreak = "break"
    private static let closed = "closed"

    static func encode(_ state: SessionState) throws -> String {
        switch state {
        case .idle: throw SessionReplayError.unsupportedTransitionState(.idle)
        case .running: running
        case .held: held
        case .onBreak: onBreak
        case .closed: closed
        }
    }

    static func decode(_ payload: String) throws -> SessionState {
        switch payload {
        case running: .running
        case held: .held
        case onBreak: .onBreak
        case closed: .closed
        default: throw SessionReplayError.unknownTransitionPayload(payload)
        }
    }

    static func reviewLabel(for payload: String) -> String {
        switch try? decode(payload) {
        case .running: "Focus resumed"
        case .held: "Held — place kept"
        case .onBreak: "Chose an intentional break"
        case .closed: "Closed the session"
        default: "Unknown state record: \(payload)"
        }
    }
}

enum SessionReplayError: Error, Equatable, Sendable {
    case unsupportedTransitionState(SessionState)
    case unknownTransitionPayload(String)
    case invalidAdjustmentPayload(String)
}

struct SessionReplay {
    struct Result: Equatable, Sendable {
        let session: Session
        let sessionID: UUID
        let taskTitle: String
        let firstAction: String
        let parkedThoughts: [String]
    }

    private let summary: LocalStore.SessionSummary

    init(summary: LocalStore.SessionSummary) {
        self.summary = summary
    }

    func replay(events: [StoredEvent], task: (title: String, firstAction: String)?) throws -> Result {
        let indexed = Array(events.enumerated())
        let transitions = try indexed.compactMap { index, event -> (Int, TransitionRecord)? in
            guard event.kind == .transition else { return nil }
            return (index, TransitionRecord(intent: nil, state: try TransitionPayload.decode(event.payload), at: event.at))
        }.sorted { lhs, rhs in
            lhs.1.at == rhs.1.at ? lhs.0 < rhs.0 : lhs.1.at < rhs.1.at
        }.map(\.1)
        let adjustments = try indexed.compactMap { index, event -> (Int, AdjustmentRecord)? in
            guard event.kind == .adjustment else { return nil }
            guard let delta = Int(event.payload) else {
                throw SessionReplayError.invalidAdjustmentPayload(event.payload)
            }
            return (index, AdjustmentRecord(delta: TimeInterval(delta), at: event.at))
        }.sorted { lhs, rhs in
            lhs.1.at == rhs.1.at ? lhs.0 < rhs.0 : lhs.1.at < rhs.1.at
        }.map(\.1)
        let records = [TransitionRecord(intent: nil, state: .idle, at: summary.startedAt)] + transitions
        return Result(
            session: Session(
                policy: TimingPolicy.named(summary.policyName), transitions: records, adjustments: adjustments),
            sessionID: summary.id,
            taskTitle: task?.title ?? "",
            firstAction: task?.firstAction ?? "",
            parkedThoughts: events.filter { $0.kind == .thoughtParked }.map(\.payload))
    }
}
