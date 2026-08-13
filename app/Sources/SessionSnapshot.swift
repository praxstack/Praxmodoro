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
    /// Rewind/forward exists only while a finite block is running and
    /// unexpired — absent, never disabled-looking (spec: "Nudges never
    /// rescue an expired block").
    let offersAdjustment: Bool
    /// The prompt-first invitation: block complete, place held, not yet
    /// waved away (spec: "Prompt-first asks gently").
    let offersBlockEndPrompt: Bool

    var hasSession: Bool { phase != .idle && phase != .closed }

    /// The only place an interval becomes a clock face.
    static func clockFace(_ remaining: TimeInterval) -> String {
        let total = Int(remaining.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// What the ambient surfaces are handed. Deliberately carries no
    /// `TimeInterval`: see `CompanionDisplay`.
    var display: CompanionDisplay {
        CompanionDisplay(
            phase: phase,
            taskLine: taskLine,
            nextAction: nextAction,
            timeText: remainingText,
            statusLine: statusLine,
            fieldSummary: accessibilitySummary,
            offersAdjustment: offersAdjustment
        )
    }
}

/// The companion surfaces' entire input: already-rendered strings and a phase.
///
/// There is no `TimeInterval` here, and that absence is the point. During
/// atom g4's review an independent validator defeated the substring guard by
/// aging `snapshot.remaining` with a `@State` counter driven by `Task.sleep` —
/// no banned token required. Handing the surfaces a value with no interval in
/// it removes the raw material for that arithmetic entirely.
///
/// This is one of three independent barriers (the others: companion surfaces
/// hold no mutable state, and take no lifecycle or async hook). Together they
/// remove the demonstrated failure mode. They are defense in depth, not a
/// proof — an author determined to parse `timeText` back into numbers could
/// still misbehave, and no unit-level check can rule that out.
struct CompanionDisplay: Equatable, Sendable {
    let phase: SessionSnapshot.Phase
    let taskLine: String
    let nextAction: String
    /// nil when there is no session — surfaces then render no clock at all.
    let timeText: String?
    let statusLine: String
    let fieldSummary: String
    /// Whether the ±1-minute nudges apply right now. A Bool on purpose: the
    /// interval ban above stays intact.
    let offersAdjustment: Bool

    var hasSession: Bool { phase != .idle && phase != .closed }
}
