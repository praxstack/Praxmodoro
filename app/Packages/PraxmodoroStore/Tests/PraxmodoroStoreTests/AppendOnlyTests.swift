import Foundation
import Testing
@testable import PraxmodoroStore

@Suite struct AppendOnlyTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testEditCreatesReferencingEventNotMutation() throws {
        let store = try LocalStore(inMemory: true)
        let sessionID = UUID()
        try store.createSession(id: sessionID, policyName: "classic", startedAt: t0)
        let originalID = try store.appendEvent(sessionID: sessionID, kind: .thoughtParked, payload: "Ask Mira about the demo laptop", at: t0)

        try store.editEvent(sessionID: sessionID, originalID: originalID, newPayload: "Ask Mira about the demo MacBook", at: t0.addingTimeInterval(300))

        let events = try store.events(sessionID: sessionID)
        #expect(events.count == 2)
        #expect(events[0].payload == "Ask Mira about the demo laptop")
        #expect(events[1].kind == .edit)
        #expect(events[1].payload == "Ask Mira about the demo MacBook")
        #expect(events[1].references == originalID)
    }
}
