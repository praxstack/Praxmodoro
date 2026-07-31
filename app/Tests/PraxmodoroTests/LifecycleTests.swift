import Foundation
import Testing
@testable import Praxmodoro
import PraxmodoroStore

@MainActor
@Suite struct LifecycleTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // Spec: app-scaffold "App lifecycle restores state" — relaunch lands the
    // user exactly where they were, remaining time derived from timestamps.
    @Test func testRelaunchIntoRunningBlockShowsFocus() throws {
        let store = try LocalStore(inMemory: true)
        var now = t0
        let before = AppModel(store: store, clock: { now })
        before.taskTitle = "Edit the conference talk outline"
        before.firstAction = "Mark the one section that already feels done."
        before.policy = .classic
        try before.begin()

        // "Relaunch": a fresh model over the same persisted container.
        now = t0.addingTimeInterval(10 * 60)
        let after = AppModel(store: store, clock: { now })
        try after.restore()
        #expect(after.surface == .focus)
        #expect(after.taskTitle == "Edit the conference talk outline")
        #expect(after.firstAction == "Mark the one section that already feels done.")
        let remaining = try #require(after.remaining(at: now))
        #expect(remaining == TimeInterval(15 * 60))
    }

    // Spec: "Fresh state lands on initiate".
    @Test func testFreshStateLandsOnInitiate() throws {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })
        try model.restore()
        #expect(model.surface == .initiate)
    }

    // A closed session does not resurrect on relaunch.
    @Test func testClosedSessionStaysClosed() throws {
        let store = try LocalStore(inMemory: true)
        var now = t0
        let before = AppModel(store: store, clock: { now })
        before.taskTitle = "Edit the outline"
        try before.begin()
        now = t0.addingTimeInterval(1200)
        try before.closeSession()

        let after = AppModel(store: store, clock: { now })
        try after.restore()
        #expect(after.surface == .initiate)
    }
}
