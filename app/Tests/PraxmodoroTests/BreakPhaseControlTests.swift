import Foundation
import PraxmodoroCore
import PraxmodoroStore
import Testing

@testable import Praxmodoro

/// A code review found two dead controls and one stacking overlay, all rooted
/// in the same blind spot: the companion surfaces were written and tested for
/// `.running` and `.held`, and nobody asked what they do during a break.
///
/// The engine's transition table has no `.hold` from `.onBreak`, so both the
/// popover's primary button and the capsule's hold button threw
/// `invalidTransition` into a `try?` and did nothing at all — a control that
/// looks live, responds to a click, and changes nothing.
@MainActor
@Suite struct BreakPhaseControlTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func modelOnBreak() throws -> AppModel {
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.firstAction = "Open the file and read the first heading"
        model.policy = .classic
        try model.begin()
        now = t0.addingTimeInterval(6 * 60)
        try model.openCheckin()
        try model.answer(.needBreak)
        return model
    }

    // The popover's primary control during a break must end the break, not
    // attempt a hold the engine will refuse.
    @Test func testPopoverPrimaryEndsTheBreak() throws {
        let model = try modelOnBreak()
        let display = model.snapshot(at: t0.addingTimeInterval(7 * 60)).display
        #expect(display.phase == .onBreak)

        var ended = false
        let popover = MenuBarPopover(
            display: display,
            actions: CompanionActions(endBreak: { ended = true }))

        #expect(popover.primaryControlLabel == "Back to focus")
        popover.primaryAction()
        #expect(ended, "the popover's break-phase primary control did nothing")
    }

    // Wired end to end: the action the scene actually installs must move the
    // session, not throw into a `try?`.
    @Test func testEndBreakActionActuallyMovesTheSession() throws {
        let model = try modelOnBreak()

        try model.endBreak()

        #expect(model.snapshot(at: t0.addingTimeInterval(7 * 60)).phase == .running)
        #expect(model.returnPending)
    }

    // The capsule must not offer a hold it cannot perform. During a break the
    // hold affordance is absent rather than dead.
    @Test func testCapsuleOffersNoHoldDuringABreak() throws {
        let model = try modelOnBreak()
        let capsule = FocusCapsule(
            display: model.snapshot(at: t0.addingTimeInterval(7 * 60)).display, actions: .inert)

        #expect(!capsule.offersHold, "the capsule offered a hold the engine refuses from .onBreak")
        #expect(!capsule.controls.contains("capsule-hold"))
    }

    // Running sessions keep the control they always had.
    @Test func testCapsuleStillOffersHoldWhileRunning() throws {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })
        model.taskTitle = "Edit the outline"
        model.policy = .classic
        try model.begin()

        let capsule = FocusCapsule(display: model.snapshot(at: t0).display, actions: .inert)

        #expect(capsule.offersHold)
        #expect(capsule.controls.contains("capsule-hold"))
    }

    @Test func testEachBreakChoiceHasAStableAccessibilityIdentifier() {
        let identifiers = [
            "break-choice-water", "break-choice-stretch",
            "break-choice-step-away", "break-choice-quiet",
        ]

        for identifier in identifiers {
            #expect(BreakSurface.controls.contains(identifier), "missing \(identifier)")
        }
    }

    // The return card remains the one visible request for attention; the
    // check-in waits behind it and appears after acknowledgement.
    @Test func testReturnCardKeepsCheckinWaitingUntilAcknowledged() throws {
        let model = try modelOnBreak()
        try model.endBreak()
        #expect(model.returnPending)

        try model.openCheckin()

        #expect(model.surface == .focus)
        #expect(model.returnPending)
        #expect(model.checkinPending)

        model.acknowledgeReturn()

        #expect(model.surface == .checkin)
        #expect(!model.returnPending)
        #expect(!model.checkinPending)
    }

    // Ending a break and then acknowledging normally is unaffected.
    @Test func testOrdinaryReturnStillWorks() throws {
        let model = try modelOnBreak()
        try model.endBreak()

        model.acknowledgeReturn()

        #expect(!model.returnPending)
        #expect(model.surface == .focus)
    }
}
