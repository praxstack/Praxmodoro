import Foundation
import PraxmodoroCore
import PraxmodoroStore
import Testing

@testable import Praxmodoro

/// Spec: companion-surfaces "Return overlay presents the exact next action".
/// Coming back from a break, the way back should be read, not remembered.
@MainActor
@Suite struct ReturnOverlayTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func modelOnBreak(nextAction: String = "Open the file and read the first heading") throws -> AppModel {
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.firstAction = nextAction
        model.policy = .classic
        try model.begin()
        now = t0.addingTimeInterval(6 * 60)
        try model.openCheckin()
        try model.answer(.needBreak)
        return model
    }

    // Spec: "Ending a break raises the overlay".
    @Test func testEndingBreakRaisesReturnOverlay() throws {
        let model = try modelOnBreak()
        #expect(!model.returnPending, "the overlay must not be waiting during the break itself")

        try model.endBreak()

        #expect(model.returnPending)
        #expect(model.surface == .focus, "the overlay sits over focus rather than replacing it")
    }

    // Spec: "Acknowledgement returns to focus" — and changes nothing else.
    @Test func testAcknowledgementLeavesPhaseUnchanged() throws {
        let model = try modelOnBreak()
        try model.endBreak()
        let phaseBefore = model.snapshot(at: t0.addingTimeInterval(7 * 60)).phase
        let remainingBefore = model.snapshot(at: t0.addingTimeInterval(7 * 60)).remaining

        model.acknowledgeReturn()

        #expect(!model.returnPending)
        #expect(model.surface == .focus)
        let after = model.snapshot(at: t0.addingTimeInterval(7 * 60))
        #expect(after.phase == phaseBefore, "acknowledging the overlay must not move the session")
        #expect(after.remaining == remainingBefore, "acknowledging the overlay must not alter remaining time")
    }

    // Acknowledging is a choice, so the field blooms once — the same
    // acknowledgement pulse every other choice gets.
    @Test func testAcknowledgementPulsesTheFieldOnce() throws {
        let model = try modelOnBreak()
        try model.endBreak()
        let before = model.fieldPulse

        model.acknowledgeReturn()

        #expect(model.fieldPulse == before + 1)
    }

    // Spec: "Return overlay presents the exact next action".
    @Test func testOverlayShowsRecordedNextAction() throws {
        let model = try modelOnBreak(nextAction: "Re-read the second paragraph")
        try model.endBreak()

        let overlay = ReturnOverlay(display: model.snapshot(at: t0.addingTimeInterval(7 * 60)).display, onAcknowledge: {})

        #expect(overlay.wayBack == "Re-read the second paragraph")
        #expect(overlay.accessibilityLabel.contains("Re-read the second paragraph"))
    }

    // Spec: "No next action recorded" — the task itself is the way back,
    // never an empty card.
    @Test func testOverlayFallsBackToTaskWhenNoNextAction() throws {
        let model = try modelOnBreak(nextAction: "")
        try model.endBreak()

        let overlay = ReturnOverlay(display: model.snapshot(at: t0.addingTimeInterval(7 * 60)).display, onAcknowledge: {})

        #expect(overlay.wayBack == "Edit the outline")
        #expect(!overlay.wayBack.isEmpty)
    }

    // Spec: "Return is not a verdict".
    @Test func testOverlayCarriesNoBreakVerdict() throws {
        let model = try modelOnBreak()
        try model.endBreak()
        let overlay = ReturnOverlay(display: model.snapshot(at: t0.addingTimeInterval(7 * 60)).display, onAcknowledge: {})

        let rendered = (ReturnOverlay.controls + [overlay.wayBack, overlay.accessibilityLabel])
            .joined(separator: " ")
            .lowercased()
        for term in ["streak", "score", "too long", "wasted", "should have", "only", "missed", "behind"] {
            #expect(!rendered.contains(term), "the return overlay evaluates the break: “\(term)”")
        }
    }

    // The overlay is presentation, not session state: it must not have
    // appended an event or changed what the store holds.
    @Test func testOverlayIsNotPersisted() throws {
        let model = try modelOnBreak()
        try model.endBreak()
        let store = try #require(model.store)
        let sessionID = try #require(model.sessionID)
        let before = try store.events(sessionID: sessionID).count

        model.acknowledgeReturn()

        #expect(
            try store.events(sessionID: sessionID).count == before,
            "acknowledging the return overlay must not append an event")
    }

    @Test func testCheckinWaitsBehindReturnOverlayWithoutDuplicateHold() throws {
        let model = try modelOnBreak()
        try model.endBreak()
        let store = try #require(model.store)
        let sessionID = try #require(model.sessionID)
        let heldBefore = try store.events(sessionID: sessionID)
            .count { $0.kind == .transition && $0.payload == "held" }

        try model.openCheckin()
        let phaseBeforeAcknowledgement = model.snapshot(at: t0.addingTimeInterval(7 * 60)).phase
        let heldAfterFirstRequest = try store.events(sessionID: sessionID)
            .count { $0.kind == .transition && $0.payload == "held" }
        try model.openCheckin()
        let heldAfterSecondRequest = try store.events(sessionID: sessionID)
            .count { $0.kind == .transition && $0.payload == "held" }

        #expect(phaseBeforeAcknowledgement == .held)
        #expect(model.surface == .focus, "the return card must remain over focus")
        #expect(model.returnPending, "a check-in request must not silently dismiss the return card")
        #expect(model.checkinPending, "the requested check-in must wait behind the card")
        #expect(heldAfterFirstRequest == heldBefore + 1)
        #expect(heldAfterSecondRequest == heldAfterFirstRequest, "a repeated request appended a duplicate hold")

        model.acknowledgeReturn()

        #expect(!model.returnPending)
        #expect(!model.checkinPending)
        #expect(model.surface == .checkin)
        #expect(
            model.snapshot(at: t0.addingTimeInterval(7 * 60)).phase == phaseBeforeAcknowledgement,
            "acknowledgement must route presentation without changing the held session")
        #expect(
            try store.events(sessionID: sessionID)
                .count { $0.kind == .transition && $0.payload == "held" } == heldAfterFirstRequest)
    }
}
