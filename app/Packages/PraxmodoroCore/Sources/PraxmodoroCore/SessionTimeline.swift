import Foundation

/// Canonical-timestamp arithmetic (spec: timer-engine). Elapsed focus is the
/// sum of `running` intervals derived from transition records; nothing counts
/// ticks. All functions are pure over (transitions, now).
public extension Session {
    /// Total focused time accumulated by `now` — running intervals only,
    /// so held and break intervals are excluded by construction.
    func focusElapsed(at now: Date) -> TimeInterval {
        var elapsed: TimeInterval = 0
        for (index, record) in transitions.enumerated() where record.state == .running {
            let end = index + 1 < transitions.count ? transitions[index + 1].at : max(now, record.at)
            elapsed += max(0, end.timeIntervalSince(record.at))
        }
        return elapsed
    }

    /// Remaining focus time, derived — nil for open-ended policies.
    /// Clamped to [0, policy.focus] so clock anomalies can never inflate it.
    func remaining(at now: Date) -> TimeInterval? {
        guard let focus = policy.focus else { return nil }
        return min(focus, max(0, focus - focusElapsed(at: now)))
    }
}

/// A recorded clock anomaly (spec: "Backwards clock adjustment").
public struct ClockAnomaly: Equatable, Sendable, Codable {
    public let observedAt: Date
    public let lastKnownAt: Date
}

public extension Session {
    /// Clock-anomaly records derived from observation events stored as
    /// transitions would be over-modeling; anomalies live alongside.
    var anomalies: [ClockAnomaly] { anomalyLog }

    /// Present a wall-clock reading to the session. If time ran backwards
    /// relative to the latest transition, record an anomaly.
    mutating func observe(at now: Date) {
        guard let last = transitions.last, now < last.at else { return }
        anomalyLog.append(ClockAnomaly(observedAt: now, lastKnownAt: last.at))
    }
}
