import Foundation
import PraxmodoroCore

/// The one projection of engine state that a surface may render.
///
/// Every surface — focus, menu-bar popover, floating capsule, return overlay —
/// renders a snapshot and nothing else. Remaining time is derived here from
/// the reconciled session, so it stays `f(transitions, now)` and a surface
/// cannot grow a second clock even by accident (spec: companion-surfaces
/// "One canonical session state for every surface").
struct SessionSnapshot: Equatable, Sendable {
    enum Phase: String, Equatable, Sendable {
        case idle, running, held, onBreak, closed

        init(_ state: SessionState) {
            switch state {
            case .idle: self = .idle
            case .running: self = .running
            case .held: self = .held
            case .onBreak: self = .onBreak
            case .closed: self = .closed
            }
        }
    }

    let phase: Phase
    let taskLine: String
    let nextAction: String
    /// nil for an open-ended policy and when no session is running.
    let remaining: TimeInterval?
    /// nil when there is no session to count — surfaces render no clock at all
    /// rather than a zero or a placeholder. "open" for open-ended policies.
    let remainingText: String?
    let statusLine: String
    let accessibilitySummary: String

    var hasSession: Bool { phase != .idle && phase != .closed }

    /// The only place an interval becomes a clock face.
    static func clockFace(_ remaining: TimeInterval) -> String {
        let total = Int(remaining.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
