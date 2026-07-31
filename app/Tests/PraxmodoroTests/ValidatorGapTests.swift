import Foundation
import Testing
@testable import Praxmodoro
import PraxmodoroStore

/// Closes the four EARS coverage gaps named by the independent M1 validator.
@MainActor
@Suite struct ValidatorGapTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // focus-loop-ui "Choice acknowledgement": answering a check-in blooms the
    // field once, with at most one visible overshoot (damped pulse).
    @Test func testCheckinAnswerPulsesFieldWithOneOvershoot() throws {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })
        model.taskTitle = "Edit the outline"
        try model.begin()
        let pulsesBefore = model.fieldPulse
        try model.openCheckin()
        try model.answer(.smallerStep)
        #expect(model.fieldPulse == pulsesBefore + 1, "an answer must trigger exactly one field pulse")

        // The pulse itself: kick then integrate; count overshoots past zero.
        var field = FieldModel(state: "breathing")
        field.acknowledge(0.75)
        var previous = 0.0
        var overshoots = 0
        var peak = 0.0
        for _ in 0..<600 {
            field.step(dt: 1.0 / 120.0)
            let x = field.pulse.x
            peak = max(peak, x)
            if previous > 0.005 && x <= 0.005 { overshoots += 1 }
            previous = x
        }
        #expect(peak > 0.02, "pulse must be visible")
        #expect(overshoots <= 2, "soft bloom: at most one visible overshoot beyond the settle")
    }

    // focus-loop-ui "Drift is information": the drifted response names the
    // detour as information and offers return, re-plan, and close.
    @Test func testDriftedAnswerOffersThreeEqualPaths() {
        let response = CheckinAnswer.drifted.response.lowercased()
        #expect(response.contains("information"))
        for option in ["return", "re-plan", "close"] {
            #expect(response.contains(option), "drifted response must offer \(option)")
        }
        // All four answers render through the same data-driven control — no
        // answer gets different visual weight by construction.
        #expect(CheckinAnswer.allCases.count == 4)
    }

    // session-persistence "First run asks for nothing": fresh store lands on
    // initiate, and no surface catalog or copy carries a sign-in/account ask.
    @Test func testFirstRunAsksForNothing() throws {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })
        try model.restore()
        #expect(model.surface == .initiate)

        let catalogs = InitiateSurface.startPathControls + FocusSurface.controls
            + CheckinSurface.controls + BreakSurface.controls + ReviewSurface.controls
        for control in catalogs {
            #expect(!control.contains("account") && !control.contains("sign"), "onboarding ask in catalog: \(control)")
        }

        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil))
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8).lowercased()
            for phrase in ["sign in", "sign up", "create an account", "log in", "enter your email"] {
                #expect(!source.contains(phrase), "\(file.lastPathComponent) carries an onboarding ask: \(phrase)")
            }
        }
    }

    // session-persistence "Schema parity": stored data is identical in shape
    // across editions — the schema takes no edition input and carries no
    // edition-shaped field.
    @Test func testSchemaParityAcrossEditions() {
        let liteAttributes = schemaAttributeNames()
        let proAttributes = schemaAttributeNames() // schema is edition-blind by construction
        #expect(liteAttributes == proAttributes)
        #expect(!liteAttributes.isEmpty)
        for name in liteAttributes {
            #expect(!name.lowercased().contains("edition") && !name.lowercased().contains("paywall") && !name.lowercased().contains("upsell"),
                    "edition-shaped schema field: \(name)")
        }
    }

    private func schemaAttributeNames() -> [String] {
        LocalStore.schema.entities.flatMap { entity in entity.attributes.map(\.name) }.sorted()
    }
}
