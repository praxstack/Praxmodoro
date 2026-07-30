import Foundation
import Testing
@testable import PraxmodoroCore

@Suite struct HoldResumeTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testHoldFreezesRemainingExactly() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        // Run for 7:34, then hold with 17:26 remaining.
        let holdAt = t0.addingTimeInterval(7 * 60 + 34)
        try session.apply(.hold, at: holdAt)
        let atHold = try #require(session.remaining(at: holdAt))
        #expect(atHold == TimeInterval(17 * 60 + 26))

        // Four minutes of held time pass; remaining must not move.
        let duringHold = try #require(session.remaining(at: holdAt.addingTimeInterval(4 * 60)))
        #expect(duringHold == atHold)

        // Resume; remaining picks up exactly where it held.
        let resumeAt = holdAt.addingTimeInterval(4 * 60)
        try session.apply(.resume, at: resumeAt)
        let atResume = try #require(session.remaining(at: resumeAt))
        #expect(atResume == atHold)
    }
}
