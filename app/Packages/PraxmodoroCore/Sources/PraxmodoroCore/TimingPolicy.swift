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

    /// Resolve a persisted policy name back to its definition. Custom policy
    /// names are self-describing, so the store keeps persisting nothing but
    /// a name and the session still reconstructs exactly.
    public static func named(_ name: String) -> TimingPolicy {
        if let custom = parseCustom(name) { return custom }
        return [gentleStart, classic, flow, recoveryFirst].first { $0.name == name } ?? classic
    }

    /// A user-constructed policy (spec: session-settings "Custom rhythm
    /// durations"). The name encodes the durations in whole seconds —
    /// `custom:a300:f2400:b480` — because the persistence schema carries only
    /// a policy name and must not change.
    public static func custom(arrival: TimeInterval?, focus: TimeInterval, suggestedBreak: TimeInterval) -> TimingPolicy {
        var segments = ["custom"]
        if let arrival { segments.append("a\(Int(arrival))") }
        segments.append("f\(Int(focus))")
        segments.append("b\(Int(suggestedBreak))")
        return TimingPolicy(
            name: segments.joined(separator: ":"),
            arrival: arrival.map { TimeInterval(Int($0)) },
            focus: TimeInterval(Int(focus)),
            suggestedBreak: TimeInterval(Int(suggestedBreak))
        )
    }

    private static func parseCustom(_ name: String) -> TimingPolicy? {
        let segments = name.split(separator: ":")
        guard segments.first == "custom" else { return nil }
        var arrival: TimeInterval?
        var focus: TimeInterval?
        var suggestedBreak: TimeInterval?
        for segment in segments.dropFirst() {
            guard let marker = segment.first, let value = Int(segment.dropFirst()), value > 0 else { return nil }
            switch marker {
            case "a": arrival = TimeInterval(value)
            case "f": focus = TimeInterval(value)
            case "b": suggestedBreak = TimeInterval(value)
            default: return nil
            }
        }
        guard let focus, let suggestedBreak else { return nil }
        return TimingPolicy(name: name, arrival: arrival, focus: focus, suggestedBreak: suggestedBreak)
    }

    public static let gentleStart = TimingPolicy(name: "gentle-start", arrival: 5 * 60, focus: 25 * 60, suggestedBreak: 5 * 60)
    public static let classic = TimingPolicy(name: "classic", arrival: nil, focus: 25 * 60, suggestedBreak: 5 * 60)
    public static let flow = TimingPolicy(name: "flow", arrival: nil, focus: nil, suggestedBreak: 5 * 60)
    public static let recoveryFirst = TimingPolicy(name: "recovery-first", arrival: nil, focus: 15 * 60, suggestedBreak: 10 * 60)
}

/// Long-break cadence: every N blocks, a longer break is *suggested* — never
/// enforced, never scored (spec: session-settings "Long-break cadence
/// suggests, never scores"). Lives in preferences, not in the policy name.
public struct LongBreakCadence: Hashable, Sendable, Codable {
    public let everyBlocks: Int
    public let length: TimeInterval

    public init(everyBlocks: Int, length: TimeInterval) {
        self.everyBlocks = everyBlocks
        self.length = length
    }
}

public extension Session {
    /// The break length to suggest at the current block-end, derived purely
    /// from transition history: completed blocks are transitions into
    /// `.break`. No counter is stored anywhere.
    func suggestedBreakLength(cadence: LongBreakCadence?) -> TimeInterval {
        guard let cadence, cadence.everyBlocks > 0 else { return policy.suggestedBreak }
        let completedBlocks = transitions.filter { $0.state == .onBreak }.count
        guard completedBlocks > 0, completedBlocks % cadence.everyBlocks == 0 else {
            return policy.suggestedBreak
        }
        return cadence.length
    }
}
