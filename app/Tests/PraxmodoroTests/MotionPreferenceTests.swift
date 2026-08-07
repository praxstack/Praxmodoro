import Foundation
import Testing

@testable import Praxmodoro
import PraxmodoroStore

/// Spec: focus-loop-ui "Complete accessibility alternates" — *"Reduce Motion
/// **or the user selects 'Motion: still'** SHALL stop the physics engine"*, and
/// `SPEC.md` M1 gate 5.
///
/// The system-level branch shipped in M1; the in-app half never did, so half of
/// a passing gate had no implementation. These tests pin the half that was
/// missing, and the composition rule between the two.
@MainActor
@Suite struct MotionPreferenceTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func model(defaults: UserDefaults) throws -> AppModel {
        AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 }, defaults: defaults)
    }

    /// Each test gets its own defaults domain so nothing leaks between them or
    /// into the real user's preferences.
    private func scratchDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func testMotionIsMovingByDefault() throws {
        #expect(try model(defaults: scratchDefaults()).motionStilled == false)
    }

    @Test func testChoosingStillnessStopsTheField() throws {
        let model = try model(defaults: scratchDefaults())

        model.setMotionStilled(true)

        #expect(model.motionStilled)
        // The composition the surfaces actually consume.
        #expect(model.fieldIsStilled(systemReduceMotion: false))
    }

    // The system setting is the floor, not a suggestion: a person who has asked
    // the whole machine for less motion must not be overridden by this app.
    @Test func testSystemReduceMotionAlwaysWins() throws {
        let model = try model(defaults: scratchDefaults())

        model.setMotionStilled(false)

        #expect(model.fieldIsStilled(systemReduceMotion: true),
                "system Reduce Motion must still the field regardless of the in-app preference")
        model.setMotionStilled(true)
        #expect(model.fieldIsStilled(systemReduceMotion: true))
    }

    @Test func testPreferenceSurvivesRelaunch() throws {
        let name = UUID().uuidString
        let defaults = scratchDefaults(name)
        try model(defaults: defaults).setMotionStilled(true)

        // A fresh model over the same defaults is what relaunch looks like.
        let relaunched = try model(defaults: defaults)

        #expect(relaunched.motionStilled, "the choice must survive relaunch")
        defaults.removePersistentDomain(forName: name)
    }

    @Test func testStillnessHasAKeyboardPath() {
        #expect(KeyboardMap.all["motion-still"] != nil, "no keyboard path for the stillness toggle")
    }

    // The control must say which state it will move you to, not which state you
    // are in — a toggle labelled with its current state is a coin flip.
    @Test func testControlNamesTheActionNotTheState() throws {
        let model = try model(defaults: scratchDefaults())

        #expect(model.motionToggleLabel == "Motion: still")
        model.setMotionStilled(true)
        #expect(model.motionToggleLabel == "Motion: gentle")
    }

    // Both directions, so the assertion cannot pass vacuously: stillness must
    // remove the physics model, and motion must restore it.
    @Test func testStandownIsARealBranchOnEverySurface() throws {
        let stilled = CompanionFieldView(state: "breathing", motionStilled: true)
        let moving = CompanionFieldView(state: "breathing", motionStilled: false)

        #expect(stilled.model == nil)
        #expect(moving.model != nil)
    }
}
