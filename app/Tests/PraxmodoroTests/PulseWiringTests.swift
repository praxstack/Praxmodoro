import Foundation
import Testing

@testable import Praxmodoro
import PraxmodoroStore

/// Spec: focus-loop-ui "Choice acknowledgement" — one damped pulse when a
/// choice lands. The physics contract kicks the pulse on five triggers:
/// check-in answer, break choice, timer toggle, begin session, and the
/// return acknowledgement.
///
/// This has been "fixed" once before. The M1 validator caught the unwired
/// pulse, and the recorded fix reached the model layer only — a test that
/// asserts a counter incremented passes whether or not any surface listens.
/// These tests pin both halves: the model triggers, and the wiring that
/// carries them to what the user actually sees.
@MainActor
@Suite struct PulseWiringTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func runningModel() throws -> AppModel {
        let model = AppModel(
            store: try LocalStore(inMemory: true), clock: { self.t0 },
            defaults: UserDefaults(suiteName: UUID().uuidString)!)
        model.taskTitle = "Edit the outline"
        try model.begin()
        return model
    }

    // ── The two triggers the model never had ─────────────────────────────

    @Test func testBeginKicksThePulse() throws {
        let model = AppModel(
            store: try LocalStore(inMemory: true), clock: { self.t0 },
            defaults: UserDefaults(suiteName: UUID().uuidString)!)
        model.taskTitle = "Edit the outline"
        let before = model.fieldPulse

        try model.begin()

        #expect(model.fieldPulse == before + 1, "beginning a session is a choice; the field must acknowledge it")
    }

    @Test func testHoldAndResumeEachKickThePulse() throws {
        let model = try runningModel()
        let before = model.fieldPulse

        try model.toggleHold()
        #expect(model.fieldPulse == before + 1)

        try model.toggleHold()
        #expect(model.fieldPulse == before + 2, "resume is a choice too")
    }

    // ── The wiring from model to surface ─────────────────────────────────

    // Pure companion surfaces receive the pulse at construction, exactly like
    // the motion override — a value, not a model reference.
    @Test func testCompanionSurfacesForwardThePulseToTheirField() throws {
        let display = try runningModel().snapshot(at: t0).display

        let popover = MenuBarPopover(display: display, actions: .inert, pulseSignal: 7)
        let capsule = FocusCapsule(display: display, actions: .inert, pulseSignal: 7)
        let overlay = ReturnOverlay(display: display, onAcknowledge: {}, pulseSignal: 7)

        #expect(popover.companionField(motionStilled: false).pulseSignal == 7)
        #expect(capsule.companionField(motionStilled: false).pulseSignal == 7)
        #expect(overlay.companionField(motionStilled: false).pulseSignal == 7)
    }

    // Every place a field is created must carry the pulse — including the
    // construction sites in the app scene and every core-loop surface. This is
    // the guard against the exact regression that already happened once: a
    // new field-bearing surface that silently drops the signal.
    //
    // A lint, and labelled as one: it checks the call site names the
    // parameter, not that the value flows. The behavioural half is above.
    @Test func testEveryFieldCallSiteForwardsThePulse() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil))

        var callSites = 0
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            // The field's own file wraps the initializer; skip it.
            if file.lastPathComponent == "CompanionFieldView.swift" { continue }
            let source = try String(contentsOf: file, encoding: .utf8)
            var search = source.startIndex
            while let hit = source.range(of: "CompanionFieldView(", range: search..<source.endIndex) {
                callSites += 1
                // The argument list ends within a bounded window; a call this
                // long without the parameter is a miss either way.
                let windowEnd = source.index(hit.lowerBound, offsetBy: 400, limitedBy: source.endIndex) ?? source.endIndex
                let window = source[hit.lowerBound..<windowEnd]
                #expect(window.contains("pulseSignal"),
                        "\(file.lastPathComponent) renders a companion field without forwarding pulseSignal")
                search = hit.upperBound
            }
        }
        #expect(callSites >= 7, "the scan must see every field call site; found \(callSites)")
    }
}
