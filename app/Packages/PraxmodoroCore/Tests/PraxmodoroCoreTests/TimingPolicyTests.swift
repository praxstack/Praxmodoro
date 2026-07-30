import Foundation
import Testing
@testable import PraxmodoroCore

@Suite struct TimingPolicyTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testGentleStartPromotesSeamlessly() throws {
        var session = Session(policy: .gentleStart, startedAt: nil)
        try session.apply(.begin, at: t0)
        // Cross the 5-minute arrival boundary: state stays running, remaining
        // is continuous, and the promotion is recorded as an ordinary event.
        let after = t0.addingTimeInterval(6 * 60)
        let reconciled = session.reconciled(at: after)
        #expect(reconciled.state(at: after) == .running)
        let remaining = try #require(reconciled.remaining(at: after))
        #expect(remaining == TimeInterval(19 * 60))
        let promotion = reconciled.transitions.first { $0.at == t0.addingTimeInterval(5 * 60) }
        #expect(promotion != nil)
        #expect(promotion?.state == .running)
    }

    @Test func testFlowNeverAutoTransitions() throws {
        var session = Session(policy: .flow, startedAt: nil)
        try session.apply(.begin, at: t0)
        let muchLater = t0.addingTimeInterval(6 * 60 * 60)
        let reconciled = session.reconciled(at: muchLater)
        #expect(reconciled.state(at: muchLater) == .running)
        #expect(reconciled.remaining(at: muchLater) == nil)
        #expect(reconciled.transitions.count == session.transitions.count)
    }
}
