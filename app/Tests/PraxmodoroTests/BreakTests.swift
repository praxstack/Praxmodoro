import Foundation
import Testing
@testable import Praxmodoro
import PraxmodoroStore

@MainActor
@Suite struct BreakTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func modelOnBreak(clock: @escaping () -> Date) throws -> AppModel {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: clock)
        model.taskTitle = "Edit the conference talk outline"
        model.capacity = "restless"
        try model.begin()
        try model.openCheckin()
        try model.answer(.needBreak)
        return model
    }

    // Spec: "Ending early is ordinary" — no notice, no penalty, no altered
    // suggestion weight; the session simply resumes.
    @Test func testEarlyEndHasNoPenaltyPath() throws {
        var now = t0
        let model = try modelOnBreak(clock: { now })
        let suggestionBefore = model.breakSuggestion

        now = t0.addingTimeInterval(5) // five seconds into the break
        try model.endBreak()
        #expect(model.surface == .focus)
        #expect(!model.isHeld)

        // No penalty-shaped records exist; the event log holds only ordinary
        // kinds, and the suggestion is unchanged by the early end.
        let events = try model.store!.events(sessionID: model.sessionID!)
        let kinds = Set(events.map(\.kind))
        #expect(kinds.isSubset(of: [.transition, .checkinAnswer, .capacityReport, .breakChoice, .thoughtParked]))
        #expect(model.breakSuggestion == suggestionBefore)
    }

    // Spec: "Suggestion provenance is disclosed" — the why names the
    // user-reported inputs and says the pattern is editable and can be off.
    @Test func testSuggestionDisclosesProvenance() throws {
        let now = t0
        let model = try modelOnBreak(clock: { now })
        let provenance = model.breakSuggestionProvenance.lowercased()
        #expect(provenance.contains("restless"), "provenance must name the reported capacity")
        #expect(provenance.contains("editable"))
        #expect(provenance.contains("turned off") || provenance.contains("disable"))
    }

    // The re-entry card carries the exact next action for the return.
    @Test func testReentryCardCarriesNextAction() throws {
        let now = t0
        let model = try modelOnBreak(clock: { now })
        model.firstAction = "Mark the one section that already feels done."
        #expect(model.reentryStep == "Mark the one section that already feels done.")
    }
}
