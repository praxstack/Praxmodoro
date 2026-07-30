import Foundation
import Testing
@testable import PraxmodoroStore

@Suite struct StoreRoundTripTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testFullSessionRoundTrip() throws {
        let store = try LocalStore(inMemory: true)
        let sessionID = UUID()
        try store.createSession(id: sessionID, policyName: "classic", startedAt: t0)
        try store.appendEvent(sessionID: sessionID, kind: .transition, payload: "running", at: t0)
        try store.appendEvent(sessionID: sessionID, kind: .checkinAnswer, payload: "smaller", at: t0.addingTimeInterval(600))
        try store.appendEvent(sessionID: sessionID, kind: .transition, payload: "break", at: t0.addingTimeInterval(900))
        try store.appendEvent(sessionID: sessionID, kind: .transition, payload: "closed", at: t0.addingTimeInterval(1200))

        // Reload from the same container: full ordered event list survives.
        let events = try store.events(sessionID: sessionID)
        #expect(events.map(\.kind) == [.transition, .checkinAnswer, .transition, .transition])
        #expect(events.map(\.payload) == ["running", "smaller", "break", "closed"])
        #expect(events.map(\.at) == [t0, t0.addingTimeInterval(600), t0.addingTimeInterval(900), t0.addingTimeInterval(1200)])
    }
}
