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

    /// Returns a session whose recorded state reflects wall-clock truth at
    /// `now`: if the block expired at or before `now`, the transition to
    /// `onBreak` is appended at the expiry instant. Idempotent.
    func reconciled(at now: Date) -> Session {
        guard let expiry = expiryInstant(), expiry <= now else { return self }
        var copy = self
        copy.transitions.append(TransitionRecord(intent: nil, state: .onBreak, at: expiry))
        return copy
    }
}
