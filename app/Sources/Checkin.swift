import Foundation

/// The four check-in answers. None is a failure state; each only changes what
/// happens next (spec: focus-loop-ui "Check-in with no failure state").
enum CheckinAnswer: String, CaseIterable {
    case stillFits = "holding"
    case smallerStep = "smaller"
    case drifted = "detour"
    case needBreak = "break"

    var label: String {
        switch self {
        case .stillFits: "Still fits — keep going"
        case .smallerStep: "Make the step smaller"
        case .drifted: "I drifted somewhere else"
        case .needBreak: "I could use a break"
        }
    }

    var detail: String {
        switch self {
        case .stillFits: "This folds away and the block continues."
        case .smallerStep: "Shrink the next action to a one-line move."
        case .drifted: "Name it as information. Choose your return freely."
        case .needBreak: "Rest is a real next step. Your place is held."
        }
    }

    /// Non-grading response copy — pinned by CheckinTests against a
    /// judgment lexicon.
    var response: String {
        switch self {
        case .stillFits: "Kept as is. The check-in folds away and the block continues."
        case .smallerStep: "New next step chosen. Smaller is a real move."
        case .drifted: "Detour noted as information. Return, re-plan, or close — all are ordinary."
        case .needBreak: "Your place is held. The intentional break is ready when you are."
        }
    }
}
