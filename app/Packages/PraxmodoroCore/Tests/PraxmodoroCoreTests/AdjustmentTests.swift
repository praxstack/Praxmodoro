import Foundation
import Testing
@testable import PraxmodoroCore

/// Spec: add-session-settings / timer-engine MODIFIED — "Rewind and forward
/// as recorded adjustments" (tasks 2.1–2.4). An adjustment is an event the
/// derivation folds in, never a mutation of anything.
@Suite struct AdjustmentTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testAdjustmentShiftsDerivationImmediately() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        let at = t0.addingTimeInterval(10 * 60)
        try session.applyAdjustment(60, at: at)
        let remaining = try #require(session.remaining(at: at))
        #expect(remaining == TimeInterval(16 * 60))
        #expect(session.expiryInstant() == t0.addingTimeInterval(26 * 60))
    }

    @Test func testAdjustmentsSurviveRelaunch() throws {
        var original = Session(policy: .classic, startedAt: nil)
        try original.apply(.begin, at: t0)
        try original.applyAdjustment(-60, at: t0.addingTimeInterval(5 * 60))
        try original.applyAdjustment(-60, at: t0.addingTimeInterval(6 * 60))

        let restored = Session(
            policy: .classic,
            transitions: original.transitions,
            adjustments: original.adjustments
        )
        let later = t0.addingTimeInterval(10 * 60)
        let remaining = try #require(restored.remaining(at: later))
        #expect(remaining == TimeInterval(13 * 60))
        #expect(restored.remaining(at: later) == original.remaining(at: later))
    }

    @Test func testSleepThroughShiftedExpiryBackdatesExactly() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        try session.applyAdjustment(60, at: t0.addingTimeInterval(10 * 60))
        // Sleep through the shifted expiry (t0+26:00); wake much later.
        let wake = t0.addingTimeInterval(50 * 60)
        let reconciled = session.reconciled(at: wake)
        #expect(reconciled.state(at: wake) == .onBreak)
        let expiry = try #require(reconciled.transitions.last)
        #expect(expiry.at == t0.addingTimeInterval(26 * 60))
    }

    @Test func testAdjustmentRejectedWhenNotRunning() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        try session.apply(.hold, at: t0.addingTimeInterval(60))
        #expect(throws: SessionError.self) {
            try session.applyAdjustment(60, at: t0.addingTimeInterval(120))
        }
        #expect(session.adjustments.isEmpty)
    }

    @Test func testAdjustmentRejectedAfterExpiry() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        #expect(throws: SessionError.self) {
            try session.applyAdjustment(60, at: t0.addingTimeInterval(30 * 60))
        }
        #expect(session.adjustments.isEmpty)
    }

    @Test func testRewindPastZeroExpiresAtTheAdjustmentInstant() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        // 30 seconds left, user rewinds a full minute: block ends now, not
        // retroactively in the past.
        let at = t0.addingTimeInterval(24 * 60 + 30)
        try session.applyAdjustment(-60, at: at)
        #expect(session.expiryInstant() == at)
    }
}

/// The second block after a break must start with full remaining — remaining
/// and expiry are scoped to the current block, not the whole session. Found
/// while designing auto-return: without this, `reconciled` re-derives
/// `onBreak` at the very instant a break ends.
@Suite struct BlockScopedRemainingTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testEndBreakStartsAFreshBlock() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        let blockEnd = t0.addingTimeInterval(25 * 60)
        try session.apply(.startBreak, at: blockEnd)
        let breakEnd = blockEnd.addingTimeInterval(5 * 60)
        try session.apply(.endBreak, at: breakEnd)

        let probe = breakEnd.addingTimeInterval(60)
        let reconciled = session.reconciled(at: probe)
        #expect(reconciled.state(at: probe) == .running)
        let remaining = try #require(reconciled.remaining(at: probe))
        #expect(remaining == TimeInterval(24 * 60))
        #expect(session.expiryInstant() == breakEnd.addingTimeInterval(25 * 60))
    }

    @Test func testHoldWithinABlockStillFreezesThePlace() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        try session.apply(.startBreak, at: t0.addingTimeInterval(25 * 60))
        let breakEnd = t0.addingTimeInterval(30 * 60)
        try session.apply(.endBreak, at: breakEnd)
        // 4 minutes into block two, hold for 10, resume.
        try session.apply(.hold, at: breakEnd.addingTimeInterval(4 * 60))
        try session.apply(.resume, at: breakEnd.addingTimeInterval(14 * 60))
        let probe = breakEnd.addingTimeInterval(15 * 60)
        let remaining = try #require(session.remaining(at: probe))
        #expect(remaining == TimeInterval(20 * 60))
    }

    @Test func testTotalFocusStillSpansAllBlocks() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        try session.apply(.startBreak, at: t0.addingTimeInterval(25 * 60))
        let breakEnd = t0.addingTimeInterval(30 * 60)
        try session.apply(.endBreak, at: breakEnd)
        let probe = breakEnd.addingTimeInterval(10 * 60)
        // The session-wide record keeps the truth for review surfaces.
        #expect(session.focusElapsed(at: probe) == TimeInterval(35 * 60))
    }
}
