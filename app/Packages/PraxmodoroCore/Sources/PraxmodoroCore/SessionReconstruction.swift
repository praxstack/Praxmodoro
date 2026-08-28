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
    /// expiry instant, and — when `autoReturn` carries a break length — a
    /// break that ran its length gains the return to focus at the canonical
    /// break-end instant. Every materialized record is backdated to its
    /// canonical timestamp, never stamped at wake time. Idempotent.
    ///
    /// Callers decide when the rhythm should continue: pass `autoReturn`
    /// only while the user is plausibly present, or an absence fills with
    /// materialized cycles nobody lived through. `witnessedSince` is the
    /// witness floor — the earliest instant the caller was present. When
    /// given, auto-return records materialize only at or after it, so a
    /// relaunch after an absence backdates the honest expiry but never
    /// fills the gap with phantom focus blocks (design decision 11).
    func reconciled(
        at now: Date,
        blockEnd: BlockEndBehaviour = .offeredDefault,
        autoReturn: TimeInterval? = nil,
        witnessedSince: Date? = nil,
        cadence: LongBreakCadence? = nil
    ) -> Session {
        var copy = self
        if let promotion = promotionInstant(), promotion <= now,
            !copy.transitions.contains(where: { $0.at == promotion && $0.intent == nil })
        {
            let index = copy.transitions.firstIndex(where: { $0.at > promotion }) ?? copy.transitions.endIndex
            copy.transitions.insert(TransitionRecord(intent: nil, state: .running, at: promotion), at: index)
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
            // Auto-return: never for flow — with no finite focus there is
            // nothing to return *to* on a rhythm, and the flow exemption
            // means no automatic transition at any instant (validator
            // finding 4). The length is cadence-aware per materialized
            // break, so the Nth break runs long (finding 6).
            if let autoReturn, autoReturn > 0, policy.focus != nil,
                let last = copy.transitions.last, last.state == .onBreak
            {
                let completed = copy.transitions.filter { $0.state == .onBreak }.count
                let length: TimeInterval =
                    if let cadence, cadence.everyBlocks > 0, completed > 0,
                        completed % cadence.everyBlocks == 0
                    {
                        cadence.length
                    } else {
                        autoReturn
                    }
                let returnAt = last.at.addingTimeInterval(length)
                if returnAt <= now, returnAt >= (witnessedSince ?? .distantPast) {
                    copy.transitions.append(
                        TransitionRecord(intent: nil, state: .running, at: returnAt))
                    advanced = true
                }
            }
        }
        return copy
    }
}
