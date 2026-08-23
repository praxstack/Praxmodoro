import Foundation
import PraxmodoroStore
import Testing

@testable import Praxmodoro

/// GitHub #3 — the check-in answers you back.
///
/// Each answer has response copy, already written and already tone-linted.
/// Until now the model stored the chosen response and nothing read it: the
/// user got one static line no matter what they said. The response is the
/// product's voice at the moment someone admits things are not working —
/// the highest-stakes copy in the loop.
@MainActor
@Suite struct CheckinResponseTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func answered(_ answer: CheckinAnswer) throws -> AppModel {
        let model = AppModel(
            store: try LocalStore(inMemory: true), clock: { self.t0 },
            defaults: UserDefaults(suiteName: UUID().uuidString)!)
        model.taskTitle = "Edit the outline"
        try model.begin()
        try model.openCheckin()
        try model.answer(answer)
        return model
    }

    // Returning answers land on focus, which shows that answer's response.
    @Test func testFocusShowsTheAnswerResponse() throws {
        for answer in [CheckinAnswer.stillFits, .smallerStep, .drifted] {
            let model = try answered(answer)
            let surface = FocusSurface(model: model, snapshot: model.snapshot(at: t0))
            #expect(model.surface == .focus)
            #expect(
                surface.checkinResponseText == answer.response,
                "\(answer) must be answered in its own words")
        }
    }

    // The break answer lands on the break surface, which acknowledges it too.
    @Test func testBreakShowsTheNeedBreakResponse() throws {
        let model = try answered(.needBreak)
        #expect(model.surface == .onBreak)
        #expect(BreakSurface(model: model).checkinResponseText == CheckinAnswer.needBreak.response)
    }

    // The response is part of each surface's rendered contract, so the
    // no-scoring catalog tests cover it from now on.
    @Test func testResponseIsInTheSurfaceCatalogs() {
        #expect(FocusSurface.controls.contains("checkin-response"))
        #expect(BreakSurface.controls.contains("checkin-response"))
    }

    // A response describes the check-in just answered — it must not haunt the
    // next session, and an unanswered session shows nothing.
    @Test func testResponseClearsForTheNextSession() throws {
        let model = try answered(.smallerStep)

        try model.closeSession()
        model.beginNextSession()
        model.taskTitle = "A fresh task"
        try model.begin()

        #expect(model.lastCheckinResponse == nil, "a new session must not inherit the old session's response")
        #expect(FocusSurface(model: model, snapshot: model.snapshot(at: t0)).checkinResponseText == nil)
    }

    // VoiceOver hears the response as part of the surface, not as a silent
    // visual change (spec: complete accessibility alternates).
    @Test func testResponseCarriesItsOwnAccessibilityText() throws {
        let model = try answered(.drifted)
        let text = try #require(
            FocusSurface(model: model, snapshot: model.snapshot(at: t0)).checkinResponseText)
        #expect(text.contains("information"), "the drifted response names the detour as information")
        #expect(!text.isEmpty && text.count < 120, "responses must stay concise enough to be spoken")
    }
}
