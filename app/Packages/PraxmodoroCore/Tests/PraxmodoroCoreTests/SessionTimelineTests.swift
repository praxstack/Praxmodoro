import Foundation
import Testing
@testable import PraxmodoroCore

@Suite struct SessionTimelineTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testRemainingDerivedNotCounted() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        // No ticks ever happened; remaining is pure arithmetic over timestamps.
        let remaining = try #require(session.remaining(at: t0.addingTimeInterval(10 * 60)))
        #expect(remaining == TimeInterval(15 * 60))
    }

    @Test func testBackwardsClockClampsAndLogsAnomaly() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        let earlier = t0.addingTimeInterval(-120)
        session.observe(at: earlier)
        #expect(session.anomalies.count == 1)
        let remaining = try #require(session.remaining(at: earlier))
        #expect(remaining <= 25 * 60)
    }
}
