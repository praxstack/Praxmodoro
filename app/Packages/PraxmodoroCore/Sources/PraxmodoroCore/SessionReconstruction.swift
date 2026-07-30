import Foundation

/// Sleep/wake/relaunch recovery (spec: timer-engine). Reconciliation evaluates
/// the pure timeline at `now` and materializes any policy expiry that occurred
/// while the process was absent — backdated to its canonical timestamp, never
/// stamped at wake time.
public extension Session {
    /// The canonical wall-clock instant the focus block expires, given the
    /// transitions so far — nil for open-ended policies or non-running tails.
    func expiryInstant() -> Date? {
        guard let focus = policy.focus,
              let last = transitions.last, last.state == .running else { return nil }
        let elapsedBeforeTail = focusElapsed(at: last.at)
        return last.at.addingTimeInterval(focus - elapsedBeforeTail)
    }

    /// The canonical instant a gentle-start arrival period completes — nil when
    /// the policy has no arrival phase or the block never ran that long.
    func promotionInstant() -> Date? {
        guard let arrival = policy.arrival,
              let firstRun = transitions.first(where: { $0.state == .running }) else { return nil }
        return firstRun.at.addingTimeInterval(arrival)
    }

    /// Returns a session whose recorded state reflects wall-clock truth at
    /// `now`: a completed gentle-start arrival is recorded as an ordinary
    /// event (state unchanged — the promotion is seamless), and a block that
    /// expired at or before `now` gains its `onBreak` transition at the expiry
    /// instant, never at wake time. Idempotent.
    func reconciled(at now: Date) -> Session {
        var copy = self
        if let promotion = promotionInstant(), promotion <= now,
           !copy.transitions.contains(where: { $0.at == promotion && $0.intent == nil }) {
            let index = copy.transitions.firstIndex(where: { $0.at > promotion }) ?? copy.transitions.endIndex
            copy.transitions.insert(TransitionRecord(intent: nil, state: .running, at: promotion), at: index)
        }
        if let expiry = copy.expiryInstant(), expiry <= now {
            copy.transitions.append(TransitionRecord(intent: nil, state: .onBreak, at: expiry))
        }
        return copy
    }
}
