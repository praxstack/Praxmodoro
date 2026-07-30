import Foundation
import Testing
@testable import PraxmodoroCore

@Suite struct SessionReconstructionTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testWakeAfterSleepShowsTrueRemaining() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        // Mac slept 8 minutes in, woke 5 minutes later. No special-casing:
        // remaining is just f(transitions, now).
        let wake = t0.addingTimeInterval(13 * 60)
        let reconciled = session.reconciled(at: wake)
        let remaining = try #require(reconciled.remaining(at: wake))
        #expect(remaining == TimeInterval(12 * 60))
        #expect(reconciled.state(at: wake) == .running)
    }

    @Test func testRelaunchRestoresHeldState() throws {
        var original = Session(policy: .classic, startedAt: nil)
        try original.apply(.begin, at: t0)
        let holdAt = t0.addingTimeInterval(7 * 60 + 34)
        try original.apply(.hold, at: holdAt)

        // Simulate relaunch: rebuild purely from persisted transitions.
        let restored = Session(policy: .classic, transitions: original.transitions)
        let later = holdAt.addingTimeInterval(45 * 60)
        let reconciled = restored.reconciled(at: later)
        #expect(reconciled.state(at: later) == .held)
        let remaining = try #require(reconciled.remaining(at: later))
        #expect(remaining == TimeInterval(17 * 60 + 26))
    }

    @Test func testExpiryWhileAsleepBackdated() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        // Wake 40 minutes after begin: the 25-minute block expired at t0+25:00.
        let wake = t0.addingTimeInterval(40 * 60)
        let reconciled = session.reconciled(at: wake)
        #expect(reconciled.state(at: wake) == .onBreak)
        let expiry = try #require(reconciled.transitions.last)
        #expect(expiry.at == t0.addingTimeInterval(25 * 60))
        #expect(expiry.intent == nil)
    }
}
