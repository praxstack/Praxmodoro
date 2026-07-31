import Foundation
import Testing
@testable import Praxmodoro
import PraxmodoroCore
import PraxmodoroStore

@MainActor
@Suite struct InitiateSurfaceTests {
    // Spec: focus-loop-ui "One-task initiation" — the start path holds exactly
    // task, first action, capacity, policy, begin. Nothing else may render on
    // it. The surface builds from this catalog (identifiers drive the views).
    @Test func testStartPathContainsOnlyLoopControls() {
        let path = InitiateSurface.startPathControls
        #expect(path == ["task-input", "first-action", "capacity-choice", "policy-choice", "begin-control"])
        let banned = ["settings", "analytics", "integrations", "sync", "blocking", "upsell", "account"]
        for control in path {
            #expect(!banned.contains(where: control.contains), "off-path control on start path: \(control)")
        }
    }

    @Test func testBeginMovesToFocusAndPersists() throws {
        let store = try LocalStore(inMemory: true)
        let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let model = AppModel(store: store, clock: { t0 })
        model.taskTitle = "Edit the conference talk outline"
        model.firstAction = "Mark the one section that already feels done."
        try model.begin()
        #expect(model.surface == .focus)
        let id = try #require(model.sessionID)
        let events = try store.events(sessionID: id)
        #expect(events.first?.kind == .transition)
        #expect(events.first?.at == t0)
    }
}

@MainActor
@Suite struct FocusSurfaceTests {
    private func startedModel() throws -> AppModel {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { Date(timeIntervalSinceReferenceDate: 800_000_000) })
        model.taskTitle = "Edit the conference talk outline"
        try model.begin()
        return model
    }

    // Spec: "Thought parking without context loss".
    @Test func testThoughtParkingKeepsFocusActive() throws {
        let model = try startedModel()
        try model.parkThought("Ask Mira about the demo laptop")
        #expect(model.surface == .focus)
        #expect(model.parkedThoughts == ["Ask Mira about the demo laptop"])
        let events = try model.store!.events(sessionID: model.sessionID!)
        #expect(events.contains { $0.kind == .thoughtParked })
    }

    // Spec: "Nothing scores the user" — no scoring identifiers anywhere on
    // the focus surface's control catalog.
    @Test func testNoScoringElementsPresent() {
        let banned = ["streak", "score", "grade", "productivity", "rank", "performance"]
        for control in FocusSurface.controls {
            #expect(!banned.contains(where: control.contains), "scoring element present: \(control)")
        }
    }

    // Remaining time is derived through the engine, never counted in the view.
    @Test func testRemainingDerivesThroughEngine() throws {
        let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { t0 })
        model.policy = .classic
        try model.begin()
        let remaining = try #require(model.remaining(at: t0.addingTimeInterval(10 * 60)))
        #expect(remaining == TimeInterval(15 * 60))
    }
}
