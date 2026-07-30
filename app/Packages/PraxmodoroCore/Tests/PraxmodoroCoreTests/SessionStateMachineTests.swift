import Foundation
import Testing
@testable import PraxmodoroCore

@Suite struct SessionStateMachineTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testValidLifecycle() throws {
        var session = Session(policy: .classic, startedAt: nil)
        try session.apply(.begin, at: t0)
        try session.apply(.hold, at: t0.addingTimeInterval(60))
        try session.apply(.resume, at: t0.addingTimeInterval(120))
        try session.apply(.startBreak, at: t0.addingTimeInterval(300))
        try session.apply(.endBreak, at: t0.addingTimeInterval(480))
        try session.apply(.close, at: t0.addingTimeInterval(600))
        let states = session.transitions.map(\.state)
        #expect(states == [.idle, .running, .held, .running, .onBreak, .running, .closed])
    }

    @Test func testInvalidTransitionReturnsTypedError() {
        var session = Session(policy: .classic, startedAt: nil)
        #expect(throws: SessionError.invalidTransition(intent: .startBreak, from: .idle)) {
            try session.apply(.startBreak, at: t0)
        }
        #expect(session.state(at: t0) == .idle)
    }
}
