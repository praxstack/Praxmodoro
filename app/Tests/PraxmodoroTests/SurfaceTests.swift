import Foundation
import PraxmodoroCore
import PraxmodoroStore
import Testing

@testable import Praxmodoro

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

@MainActor
@Suite struct SurfaceRoutingIntentTests {
    private var sourcesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    @Test func testBeginNextSessionPreservesTaskAndPreferences() throws {
        let defaultsName = "SurfaceRoutingIntentTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let model = AppModel(
            store: try LocalStore(inMemory: true),
            clock: { Date(timeIntervalSinceReferenceDate: 800_000_000) }, defaults: defaults)
        let rhythm = RhythmPreferences(
            focusPresets: [42 * 60], breakPresets: [7 * 60], blockEnd: .promptFirst,
            autoReturn: true)
        let sound = SoundPreferences(masterVolume: 0.35)
        let notifications = NotificationPreferences(
            blockEndText: "A custom block note.", breakEndText: "A custom break note.")
        model.taskTitle = "Edit the conference talk outline"
        model.firstAction = "Mark the section that already feels done."
        model.setRhythm(rhythm)
        model.setSound(sound)
        model.setNotifications(notifications)
        try model.begin()
        try model.parkThought("Ask Mira about the demo laptop")
        try model.closeSession()
        #expect(model.surface == .review)
        let reviewedSession = model.session
        let reviewedSessionID = model.sessionID
        let reviewedThoughts = model.parkedThoughts

        model.beginNextSession()

        #expect(model.surface == .initiate)
        #expect(model.taskTitle == "Edit the conference talk outline")
        #expect(model.firstAction == "Mark the section that already feels done.")
        #expect(model.rhythm == rhythm)
        #expect(model.sound == sound)
        #expect(model.notifications == notifications)
        #expect(model.session == reviewedSession)
        #expect(model.sessionID == reviewedSessionID)
        #expect(model.parkedThoughts == reviewedThoughts)
    }

    @Test func testSurfaceSetterIsPrivateToTheModel() throws {
        let source = try String(
            contentsOf: sourcesRoot.appendingPathComponent("AppModel.swift"), encoding: .utf8)
        #expect(
            source.range(
                of: #"private\(set\)\s+var\s+surface\s*:\s*Surface"#,
                options: .regularExpression) != nil,
            "AppModel.surface must be read-only outside the model")
    }

    @Test func testSurfacesDoNotAssignModelSurface() throws {
        let surfaces = sourcesRoot.appendingPathComponent("Surfaces")
        let enumerator = try #require(
            FileManager.default.enumerator(at: surfaces, includingPropertiesForKeys: nil))
        var scanned = 0

        for case let file as URL in enumerator
        where file.pathExtension == "swift" {
            scanned += 1
            let source = try String(contentsOf: file, encoding: .utf8)
            #expect(
                source.range(of: #"model\.surface\s*="#, options: .regularExpression) == nil,
                "\(file.lastPathComponent) assigns model.surface directly")
        }

        #expect(scanned > 0, "surface source scan must not be empty")
    }
}
