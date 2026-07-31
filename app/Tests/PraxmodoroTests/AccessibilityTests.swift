import Foundation
import Testing
@testable import Praxmodoro
import PraxmodoroStore

/// Spec: focus-loop-ui "Complete accessibility alternates". The runtime
/// standdown is pinned in CompanionFieldTests; this suite covers the
/// VoiceOver field summary, the full keyboard path, and the structural
/// guarantees for Reduce Transparency / Increase Contrast.
@MainActor
@Suite struct AccessibilityTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // VoiceOver reads a concise state summary for the field region.
    @Test func testVoiceOverFieldSummary() throws {
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.policy = .classic
        try model.begin()
        now = t0.addingTimeInterval(8 * 60)
        #expect(model.fieldAccessibilitySummary(at: now) == "Companion: breathing, 17 minutes remaining")
        try model.toggleHold()
        #expect(model.fieldAccessibilitySummary(at: now).hasPrefix("Companion: holding your place"))

        let flowModel = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })
        flowModel.taskTitle = "Open block"
        flowModel.policy = .flow
        try flowModel.begin()
        #expect(flowModel.fieldAccessibilitySummary(at: t0) == "Companion: breathing, open-ended block")
    }

    // Every loop action is keyboard-reachable: the keyboard map covers the
    // whole path begin -> hold -> check-in answers -> break end -> new session.
    @Test func testFullKeyboardLoop() {
        let map = KeyboardMap.all
        let required = ["begin", "hold-toggle", "checkin-1", "checkin-2", "checkin-3", "checkin-4", "break-ready", "new-session"]
        for action in required {
            #expect(map.keys.contains(action), "no keyboard path for \(action)")
        }
    }

    // Structural: no translucent materials without a Reduce Transparency
    // gate, and no hardcoded text colors (system semantic styles adapt to
    // Increase Contrast automatically; the decorative field is a11y-hidden).
    @Test func testNoUngatedTranslucencyOrHardcodedTextColors() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil))
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            if source.contains("Material") || source.contains(".ultraThin") {
                #expect(source.contains("accessibilityReduceTransparency"),
                        "\(file.lastPathComponent) uses a material without a Reduce Transparency gate")
            }
            if file.lastPathComponent != "CompanionFieldView.swift" {
                #expect(!source.contains(".foregroundColor(Color(red:"),
                        "\(file.lastPathComponent) hardcodes a text color; use semantic styles")
            }
        }
    }
}
