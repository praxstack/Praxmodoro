import Foundation

/// Session timing policies are data, never doctrine: no policy is "optimal"
/// (research w2-breaks-adhd-falsification-001). `focus == nil` means open-ended.
public struct TimingPolicy: Hashable, Sendable, Codable {
    public let name: String
    /// Optional arrival period folded seamlessly into the block (gentle start).
    public let arrival: TimeInterval?
    /// Total focus duration including arrival; nil = open-ended (flow).
    public let focus: TimeInterval?
    /// Suggested break length; user-steerable, never enforced.
    public let suggestedBreak: TimeInterval

    public init(name: String, arrival: TimeInterval?, focus: TimeInterval?, suggestedBreak: TimeInterval) {
        self.name = name
        self.arrival = arrival
        self.focus = focus
        self.suggestedBreak = suggestedBreak
    }

    public static let gentleStart = TimingPolicy(name: "gentle-start", arrival: 5 * 60, focus: 25 * 60, suggestedBreak: 5 * 60)
    public static let classic = TimingPolicy(name: "classic", arrival: nil, focus: 25 * 60, suggestedBreak: 5 * 60)
    public static let flow = TimingPolicy(name: "flow", arrival: nil, focus: nil, suggestedBreak: 5 * 60)
    public static let recoveryFirst = TimingPolicy(name: "recovery-first", arrival: nil, focus: 15 * 60, suggestedBreak: 10 * 60)
}
