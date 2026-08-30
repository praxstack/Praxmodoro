import Foundation
import PraxmodoroCore
import PraxmodoroStore
import Testing

@testable import Praxmodoro

/// Spec: companion-surfaces "Floating focus capsule stays above other windows"
/// and "Surfaces agree at one instant".
@MainActor
@Suite struct FocusCapsuleTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func runningModel(policy: TimingPolicy = .classic) throws -> AppModel {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })
        model.taskTitle = "Edit the outline"
        model.firstAction = "Open the file and read the first heading"
        model.policy = policy
        try model.begin()
        return model
    }

    // The capsule shows the task and the time, and offers hold/resume.
    @Test func testCapsuleShowsTaskTimeAndHold() throws {
        let model = try runningModel()
        let capsule = FocusCapsule(display: model.snapshot(at: t0.addingTimeInterval(3 * 60)).display, actions: .inert)

        #expect(capsule.taskText == "Edit the outline")
        #expect(capsule.timeText == "22:00")
        #expect(capsule.statusText == "Focusing")
        #expect(capsule.controls == ["capsule-status", "capsule-task", "capsule-time", "capsule-hold"])
        #expect(capsule.accessibilityLabel.hasPrefix("Focus capsule:"))
    }

    // Spec: "Capsule shows the same time as the main window" — and the
    // popover agrees too. One snapshot, one set of strings.
    @Test func testThreeSurfacesAgreeAtOneInstant() throws {
        let model = try runningModel()
        let instant = t0.addingTimeInterval(11 * 60 + 30)
        let snapshot = model.snapshot(at: instant)

        let focus = FocusSurface(model: model, snapshot: snapshot)
        let capsule = FocusCapsule(display: snapshot.display, actions: .inert)
        let popover = MenuBarPopover(display: snapshot.display, actions: .inert)

        #expect(focus.taskText == snapshot.taskLine)
        #expect(focus.remainingReadout.text == snapshot.remainingText)
        #expect(focus.statusText == snapshot.statusLine)
        #expect(focus.taskText == capsule.taskText)
        #expect(focus.remainingReadout.text == capsule.timeText)
        #expect(focus.statusText == capsule.statusText)
        #expect(focus.statusText == popover.statusText)
        #expect(capsule.timeText == snapshot.remainingText)
        #expect(popover.timeText == snapshot.remainingText)
        #expect(capsule.timeText == popover.timeText)
        #expect(capsule.taskText == snapshot.taskLine)
        #expect(capsule.accessibilityLabel.contains(snapshot.statusLine))
        #expect(popover.statusText == snapshot.statusLine)
        #expect(snapshot.remainingText == "13:30")
    }

    // Held is held everywhere at once.
    @Test func testCapsuleReflectsHeldPhase() throws {
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.policy = .classic
        try model.begin()
        now = t0.addingTimeInterval(4 * 60)
        try model.toggleHold()

        let capsule = FocusCapsule(display: model.snapshot(at: now).display, actions: .inert)

        #expect(capsule.display.phase == .held)
        #expect(capsule.timeText == "21:00")
        #expect(capsule.accessibilityLabel.contains("Held"))
    }

    // Spec: "Capsule toggles from the keyboard".
    @Test func testCapsuleCommandHasKeyboardPath() {
        #expect(KeyboardMap.all["toggle-capsule"] != nil, "the capsule has no keyboard path")
    }

    // Spec: "Capsule is suppressed at launch" and "stays above other
    // windows". Both are declarative scene configuration, so the assertion is
    // that the configuration is actually declared; the launch behavior itself
    // is asserted end-to-end by the first-run UI test.
    @Test func testCapsuleSceneIsFloatingAndLaunchSuppressed() throws {
        let appSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources").appendingPathComponent("PraxmodoroApp.swift"),
            encoding: .utf8)

        #expect(appSource.contains("windowLevel(.floating)"), "the capsule window is not above other windows")
        #expect(appSource.contains("defaultLaunchBehavior(.suppressed)"), "the capsule would open itself at launch")
        #expect(appSource.contains("FocusCapsule("), "no scene renders the capsule")
    }
}
