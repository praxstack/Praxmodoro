import Foundation
import PraxmodoroCore
import Testing

@testable import Praxmodoro
import PraxmodoroStore

/// Spec: companion-surfaces "Accessibility alternates on every companion
/// surface". The alternates ship with the surfaces, not after them.
@MainActor
@Suite struct CompanionAccessibilityTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func display(hold: Bool = false) throws -> CompanionDisplay {
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.firstAction = "Open the file and read the first heading"
        model.policy = .classic
        try model.begin()
        now = t0.addingTimeInterval(9 * 60)
        if hold { try model.toggleHold() }
        return model.snapshot(at: now).display
    }

    // The set is complete: every surface the change promises exists.
    @Test func testAllThreeCompanionSurfacesExist() throws {
        let surfacesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent("Surfaces")
        for name in ["MenuBarPopover.swift", "FocusCapsule.swift", "ReturnOverlay.swift", "RemainingReadout.swift"] {
            #expect(FileManager.default.fileExists(atPath: surfacesDir.appendingPathComponent(name).path),
                    "companion surface \(name) is missing")
        }
    }

    // Spec: "Reduce Motion standdown on the new surfaces" — the physics model
    // is never instantiated, exactly as on the M1 surfaces. Asserted at
    // runtime through each surface's own field, not inferred from source.
    @Test func testCompanionSurfacesStandDownUnderReduceMotion() throws {
        let display = try display()
        let popover = MenuBarPopover(display: display, actions: .inert)
        let capsule = FocusCapsule(display: display, actions: .inert)
        let overlay = ReturnOverlay(display: display, onAcknowledge: {})

        #expect(popover.companionField(motionStilled: true).model == nil)
        #expect(capsule.companionField(motionStilled: true).model == nil)
        #expect(overlay.companionField(motionStilled: true).model == nil)

        // And the standdown must be a real branch: with motion allowed, the
        // physics model exists. Otherwise the assertions above prove nothing.
        #expect(popover.companionField(motionStilled: false).model != nil)
        #expect(capsule.companionField(motionStilled: false).model != nil)
        #expect(overlay.companionField(motionStilled: false).model != nil)
    }

    // Spec: "VoiceOver reads each companion surface" — a concise label naming
    // the surface and the current session state.
    @Test func testCompanionSurfacesCarryVoiceOverLabels() throws {
        let running = try display()
        let held = try display(hold: true)

        let popover = MenuBarPopover(display: running, actions: .inert)
        #expect(popover.accessibilityLabel == "Praxmodoro: Focusing, 16:00 left")
        #expect(MenuBarPopover(display: held, actions: .inert).accessibilityLabel.contains("Held"))

        let capsule = FocusCapsule(display: running, actions: .inert)
        #expect(capsule.accessibilityLabel == "Focus capsule: Edit the outline, 16:00 left, Focusing")

        let overlay = ReturnOverlay(display: running, onAcknowledge: {})
        #expect(overlay.accessibilityLabel == "Welcome back. Pick it up here: Open the file and read the first heading")

        for label in [popover.accessibilityLabel, capsule.accessibilityLabel, overlay.accessibilityLabel] {
            #expect(!label.isEmpty)
            #expect(label.count < 120, "a VoiceOver label should be concise, not a paragraph: \(label)")
        }
    }

    // Every companion surface's controls are reachable by keyboard, and the
    // whole loop still has a path (spec: focus-loop-ui "Full keyboard loop").
    @Test func testCompanionSurfacesAreKeyboardReachable() {
        let map = KeyboardMap.all
        for action in ["begin", "hold-toggle", "checkin-now", "checkin-1", "checkin-2", "checkin-3", "checkin-4",
                       "break-ready", "new-session", "toggle-capsule", "return-continue"] {
            #expect(map[action] != nil, "no keyboard path for \(action)")
        }
    }
}
