import Foundation

/// What happens when a finite block reaches its expiry (spec:
/// add-session-settings "Autostart behaviour is the user's choice"). The
/// engine records the consequence; presentation belongs to surfaces. The
/// flow policy is structurally exempt: with no finite focus there is no
/// expiry instant, so no behaviour can ever fire.
public enum BlockEndBehaviour: String, Sendable, Equatable, Codable {
    /// The break simply begins at the canonical expiry instant; declining or
    /// ending it stays one ordinary action.
    case offeredDefault = "offered-default"
    /// The block completes into a held place; the break starts only on an
    /// explicit accept, recorded at accept time. The shipped default.
    case promptFirst = "prompt-first"
    /// Nothing is recorded; the block-end is presented and the user chooses.
    case manual
}

/// Sleep/wake/relaunch recovery (spec: timer-engine). Reconciliation evaluates
/// the pure timeline at `now` and materializes any policy expiry that occurred
/// while the process was absent — backdated to its canonical timestamp, never
/// stamped at wake time.
public extension Session {
    /// The canonical wall-clock instant the current block expires, given the
    /// transitions and adjustments so far — nil for open-ended policies or
    /// non-running tails. A rewind past zero expires at the rewind instant,
    /// never retroactively before it.
    func expiryInstant() -> Date? {
        guard let focus = policy.focus,
            let last = transitions.last, last.state == .running
        else { return nil }
        let target = focus + blockAdjustmentTotal()
        let elapsedBeforeTail = blockElapsed(at: last.at)
        let derived = last.at.addingTimeInterval(target - elapsedBeforeTail)
        guard let start = currentBlockStart(),
            let lastNudge = adjustmentLog.filter({ $0.at >= start }).map(\.at).max()
        else { return derived }
        return max(derived, lastNudge)
    }

    /// The canonical end of the active break, including a due long-break
    /// cadence — nil unless the recorded tail is a break.
    func breakEndInstant(cadence: LongBreakCadence?) -> Date? {
        guard let last = transitions.last, last.state == .onBreak else { return nil }
        return last.at.addingTimeInterval(suggestedBreakLength(cadence: cadence))
    }

    /// The canonical instant a gentle-start arrival period completes — nil when
    /// the policy has no arrival phase or the block never ran that long.
    func promotionInstant() -> Date? {
        guard let arrival = policy.arrival,
            let firstRun = transitions.first(where: { $0.state == .running })
        else { return nil }
        return firstRun.at.addingTimeInterval(arrival)
    }

    /// Returns a session whose recorded state reflects wall-clock truth at
    /// `now`: a completed gentle-start arrival is recorded as an ordinary
    /// event (state unchanged — the promotion is seamless), a block that
    /// expired at or before `now` gains the consequence of `blockEnd` at the
    /// expiry instant, and — when `autoReturn` is enabled for a break whose
    /// end occurred after `autoReturnAfter` — a completed break gains the
    /// return to focus at the canonical break-end instant. Every record is
    /// backdated to its
    /// canonical timestamp, never stamped at wake time. Idempotent.
    ///
    /// `autoReturnAfter` is the process-live fence: breaks ending at or before
    /// it remain open, so an absence cannot fill with cycles nobody lived.
    func reconciled(
        at now: Date,
        blockEnd: BlockEndBehaviour = .offeredDefault,
        autoReturn: Bool = false,
        autoReturnAfter: Date? = nil,
        cadence: LongBreakCadence? = nil
    ) -> Session {
        var copy = self
        if let promotion = promotionInstant(), promotion <= now,
            !copy.transitions.contains(where: { $0.at == promotion && $0.intent == nil })
        {
            let index = copy.transitions.firstIndex(where: { $0.at > promotion }) ?? copy.transitions.endIndex
            // Seamless means state-preserving: only record promotion when
            // the session was actually running at the promotion instant.
            if index > 0, copy.transitions[index - 1].state == .running {
                copy.transitions.insert(TransitionRecord(intent: nil, state: .running, at: promotion), at: index)
            }
        }
        var advanced = true
        while advanced {
            advanced = false
            if let expiry = copy.expiryInstant(), expiry <= now {
                switch blockEnd {
                case .offeredDefault:
                    copy.transitions.append(TransitionRecord(intent: nil, state: .onBreak, at: expiry))
                    advanced = true
                case .promptFirst:
                    copy.transitions.append(TransitionRecord(intent: nil, state: .held, at: expiry))
                case .manual:
                    break
                }
            }
            // Auto-return: never for flow, never for an unwitnessed break,
            // and always at Core's cadence-aware canonical end.
            if autoReturn, policy.focus != nil, let autoReturnAfter,
                let breakEnd = copy.breakEndInstant(cadence: cadence),
                breakEnd > autoReturnAfter, breakEnd <= now
            {
                copy.transitions.append(TransitionRecord(intent: nil, state: .running, at: breakEnd))
                advanced = true
            }
        }
        return copy
    }
}
