import Foundation
import Testing
@testable import PraxmodoroCore

/// Spec: add-session-settings — "Autostart behaviour is the user's choice"
/// plus the timer-engine autostart/auto-return scenarios (tasks 3.1–3.6).
@Suite struct BlockEndBehaviourTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func running() throws -> Session {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        return session
    }

    @Test func testOfferedDefaultRecordsBreakAtCanonicalExpiry() throws {
        let session = try running()
        let wake = t0.addingTimeInterval(40 * 60)
        let reconciled = session.reconciled(at: wake, blockEnd: .offeredDefault)
        #expect(reconciled.state(at: wake) == .onBreak)
        #expect(reconciled.transitions.last?.at == t0.addingTimeInterval(25 * 60))
    }

    @Test func testPromptFirstHoldsThePlaceAtExpiry() throws {
        let session = try running()
        let after = t0.addingTimeInterval(26 * 60)
        let reconciled = session.reconciled(at: after, blockEnd: .promptFirst)
        #expect(reconciled.state(at: after) == .held)
        let hold = try #require(reconciled.transitions.last)
        #expect(hold.at == t0.addingTimeInterval(25 * 60))
        #expect(hold.intent == nil)
        // Accepting later records the break at accept time, not expiry time.
        var accepted = reconciled
        let acceptAt = t0.addingTimeInterval(28 * 60)
        try accepted.apply(.startBreak, at: acceptAt)
        #expect(accepted.state(at: acceptAt) == .onBreak)
        #expect(accepted.transitions.last?.at == acceptAt)
    }

    @Test func testPromptFirstIsIdempotentAcrossReconciles() throws {
        let session = try running()
        let after = t0.addingTimeInterval(26 * 60)
        let once = session.reconciled(at: after, blockEnd: .promptFirst)
        let twice = once.reconciled(at: after.addingTimeInterval(60), blockEnd: .promptFirst)
        #expect(twice.transitions.count == once.transitions.count)
    }

    @Test func testManualRecordsNothingAtExpiry() throws {
        let session = try running()
        let after = t0.addingTimeInterval(30 * 60)
        let reconciled = session.reconciled(at: after, blockEnd: .manual)
        #expect(reconciled.state(at: after) == .running)
        #expect(reconciled.transitions.count == session.transitions.count)
        #expect(reconciled.remaining(at: after) == 0)
    }

    @Test func testFlowIsExemptFromEveryBehaviour() throws {
        var session = Session(policy: .flow, startedAt: nil)
        try session.apply(.begin, at: t0)
        let later = t0.addingTimeInterval(6 * 60 * 60)
        for behaviour in [BlockEndBehaviour.offeredDefault, .promptFirst, .manual] {
            let reconciled = session.reconciled(at: later, blockEnd: behaviour, autoReturn: 5 * 60)
            #expect(reconciled.state(at: later) == .running)
            #expect(reconciled.transitions.count == session.transitions.count)
        }
    }

    @Test func testGentleStartPromotionUnchangedUnderPromptFirst() throws {
        var session = Session(policy: .gentleStart, startedAt: nil)
        try session.apply(.begin, at: t0)
        let after = t0.addingTimeInterval(6 * 60)
        let reconciled = session.reconciled(at: after, blockEnd: .promptFirst)
        #expect(reconciled.state(at: after) == .running)
        #expect(reconciled.remaining(at: after) == TimeInterval(19 * 60))
    }

    @Test func testAutoReturnRecordsAtCanonicalBreakEnd() throws {
        var session = try running()
        let blockEnd = t0.addingTimeInterval(25 * 60)
        try session.apply(.startBreak, at: blockEnd)
        // Sleep across the break's end; wake later. The return is backdated.
        let wake = blockEnd.addingTimeInterval(9 * 60)
        let reconciled = session.reconciled(at: wake, blockEnd: .manual, autoReturn: 5 * 60)
        #expect(reconciled.state(at: wake) == .running)
        let ret = try #require(reconciled.transitions.last)
        #expect(ret.at == blockEnd.addingTimeInterval(5 * 60))
        #expect(ret.intent == nil)
        // The new block's remaining is fresh and derives from the backdated start.
        let remaining = try #require(reconciled.remaining(at: wake))
        #expect(remaining == TimeInterval(21 * 60))
    }

    @Test func testAutoReturnOffKeepsBreaksOpenEnded() throws {
        var session = try running()
        try session.apply(.startBreak, at: t0.addingTimeInterval(25 * 60))
        let muchLater = t0.addingTimeInterval(3 * 60 * 60)
        let reconciled = session.reconciled(at: muchLater, blockEnd: .offeredDefault)
        #expect(reconciled.state(at: muchLater) == .onBreak)
        #expect(reconciled.transitions.count == session.transitions.count)
    }

    @Test func testFullRhythmMaterializesAcrossAGap() throws {
        // offeredDefault + autoReturn: a 62-minute absence materializes the
        // whole 25+5 rhythm at canonical instants — two full cycles in.
        let session = try running()
        let wake = t0.addingTimeInterval(62 * 60)
        let reconciled = session.reconciled(at: wake, blockEnd: .offeredDefault, autoReturn: 5 * 60)
        let instants = reconciled.transitions.map { $0.at.timeIntervalSince(t0) / 60 }
        #expect(instants.contains(25))
        #expect(instants.contains(30))
        #expect(instants.contains(55))
        #expect(instants.contains(60))
        #expect(reconciled.state(at: wake) == .running)
    }
}

/// Validator findings 4, 6, and task 3.5 (independent review, 2026-08-13):
/// flow must be exempt from auto-return on breaks too, the auto-return
/// length must honour the cadence at the boundary, and the behaviour is
/// read at expiry-processing time.
@Suite struct BlockEndBehaviourFindingsTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testFlowBreakNeverAutoReturns() throws {
        var session = Session(policy: .flow, startedAt: nil)
        try session.apply(.begin, at: t0)
        try session.apply(.startBreak, at: t0.addingTimeInterval(50 * 60))
        let later = t0.addingTimeInterval(4 * 60 * 60)
        for behaviour in [BlockEndBehaviour.offeredDefault, .promptFirst, .manual] {
            let reconciled = session.reconciled(at: later, blockEnd: behaviour, autoReturn: 5 * 60)
            #expect(reconciled.state(at: later) == .onBreak, "a flow break must stay open-ended")
            #expect(reconciled.transitions.count == session.transitions.count)
        }
    }

    @Test func testAutoReturnHonoursCadenceAtTheBoundary() throws {
        // Cadence every 2 blocks, long break 10 minutes, ordinary 5. The
        // second break must auto-return after 10 minutes, not 5.
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        let cadence = LongBreakCadence(everyBlocks: 2, length: 10 * 60)
        // Materialize two full cycles: block 25 + break 5 + block 25, then
        // the second break-end is boundary + 10, not + 5.
        let wake = t0.addingTimeInterval(80 * 60)
        let reconciled = session.reconciled(
            at: wake, blockEnd: .offeredDefault, autoReturn: 5 * 60, cadence: cadence)
        let instants = reconciled.transitions.map { Int($0.at.timeIntervalSince(t0) / 60) }
        #expect(instants.contains(55), "second block ends at 55")
        #expect(instants.contains(65), "second break is the long one: returns at 65, not 60")
        #expect(!instants.contains(60), "the ordinary length must not fire at the cadence boundary")
    }

    @Test func testBehaviourIsReadAtProcessingTime() throws {
        // The same recorded history yields different consequences depending
        // on the behaviour in force when the expiry is processed — the
        // setting is a parameter of reconciliation, never captured at begin.
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        let after = t0.addingTimeInterval(26 * 60)
        #expect(session.reconciled(at: after, blockEnd: .manual).state(at: after) == .running)
        #expect(session.reconciled(at: after, blockEnd: .offeredDefault).state(at: after) == .onBreak)
        #expect(session.reconciled(at: after, blockEnd: .promptFirst).state(at: after) == .held)
    }
}
