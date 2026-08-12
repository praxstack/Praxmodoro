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

    /// The instant the current focus block began: the last entry into
    /// `running` from a break, or the first `running` record. Promotions and
    /// resumes continue a block; only a break ending starts a new one.
    func currentBlockStart() -> Date? {
        var start: Date?
        var previous = SessionState.idle
        for record in transitions {
            if record.state == .running, start == nil || previous == .onBreak {
                start = record.at
            }
            previous = record.state
        }
        return start
    }

    /// Focused time within the current block only — remaining and expiry are
    /// block-scoped so a block after a break starts whole (spec: timer-engine
    /// "User-steerable timing policies").
    func blockElapsed(at now: Date) -> TimeInterval {
        guard let start = currentBlockStart() else { return 0 }
        var elapsed: TimeInterval = 0
        for (index, record) in transitions.enumerated()
        where record.state == .running && record.at >= start {
            let end = index + 1 < transitions.count ? transitions[index + 1].at : max(now, record.at)
            elapsed += max(0, end.timeIntervalSince(record.at))
        }
        return elapsed
    }

    /// Adjustments belonging to the current block.
    internal func blockAdjustmentTotal() -> TimeInterval {
        guard let start = currentBlockStart() else { return 0 }
        return adjustmentLog.filter { $0.at >= start }.reduce(0) { $0 + $1.delta }
    }

    /// Remaining focus time, derived — nil for open-ended policies. Clamped
    /// to [0, adjusted focus] so clock anomalies can never inflate it.
    func remaining(at now: Date) -> TimeInterval? {
        guard let focus = policy.focus else { return nil }
        let target = focus + blockAdjustmentTotal()
        return min(target, max(0, target - blockElapsed(at: now)))
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
