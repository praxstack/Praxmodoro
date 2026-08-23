import Foundation
import PraxmodoroCore
import PraxmodoroStore
import Testing
@testable import Praxmodoro

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

    @Test func testKnownTransitionPayloadsRoundTripAndDescribeReview() throws {
        let cases: [(SessionState, String, String)] = [
            (.running, "running", "Focus resumed"),
            (.held, "held", "Held — place kept"),
            (.onBreak, "break", "Chose an intentional break"),
            (.closed, "closed", "Closed the session"),
        ]

        for (state, payload, label) in cases {
            #expect(try TransitionPayload.encode(state) == payload)
            #expect(try TransitionPayload.decode(payload) == state)
            #expect(TransitionPayload.reviewLabel(for: payload) == label)
        }
        #expect(replayError { _ = try TransitionPayload.encode(.idle) } == .unsupportedTransitionState(.idle))
    }

    @Test func testReplayRejectsUnknownTransition() throws {
        let fixture = try replayFixture(events: [(.transition, "teleported", t0)])

        #expect(
            replayError {
                _ = try SessionReplay(summary: fixture.summary).replay(events: fixture.events, task: nil)
            } == .unknownTransitionPayload("teleported"))
    }

    @Test func testReplayRejectsMalformedAdjustment() throws {
        let fixture = try replayFixture(events: [
            (.transition, "running", t0),
            (.adjustment, "1.5", t0.addingTimeInterval(1)),
        ])

        #expect(
            replayError {
                _ = try SessionReplay(summary: fixture.summary).replay(events: fixture.events, task: nil)
            } == .invalidAdjustmentPayload("1.5"))
    }

    @Test func testReplayOrdersTransitionsAndAdjustmentsByTimestampThenInputIndex() throws {
        let sharedTransitionTime = t0.addingTimeInterval(20)
        let sharedAdjustmentTime = t0.addingTimeInterval(30)
        let fixture = try replayFixture(events: [
            (.transition, "held", sharedTransitionTime),
            (.adjustment, "120", sharedAdjustmentTime),
            (.transition, "running", t0.addingTimeInterval(10)),
            (.adjustment, "-60", sharedAdjustmentTime),
            (.transition, "break", sharedTransitionTime),
        ])

        let result = try SessionReplay(summary: fixture.summary).replay(
            events: fixture.events,
            task: (title: "Write the outline", firstAction: "Name the first section"))

        #expect(result.sessionID == fixture.sessionID)
        #expect(result.taskTitle == "Write the outline")
        #expect(result.firstAction == "Name the first section")
        #expect(result.session.policy == .classic)
        #expect(result.session.transitions.map(\.state) == [.idle, .running, .held, .onBreak])
        #expect(result.session.transitions.map(\.at) == [t0, t0.addingTimeInterval(10), sharedTransitionTime, sharedTransitionTime])
        #expect(result.session.adjustments.map(\.delta) == [120, -60])
        #expect(result.session.adjustments.map(\.at) == [sharedAdjustmentTime, sharedAdjustmentTime])
    }

    @Test func testReplayUsesEmptyTaskFallbackAndPreservesThoughtStoreOrder() throws {
        let fixture = try replayFixture(events: [
            (.transition, "running", t0),
            (.thoughtParked, "second by timestamp", t0.addingTimeInterval(20)),
            (.thoughtParked, "first by timestamp", t0.addingTimeInterval(10)),
        ])

        let result = try SessionReplay(summary: fixture.summary).replay(events: fixture.events, task: nil)

        #expect(result.taskTitle.isEmpty)
        #expect(result.firstAction.isEmpty)
        #expect(result.parkedThoughts == ["second by timestamp", "first by timestamp"])
        #expect(result.session.state(at: t0) == .running)
    }

    @Test func testReplayReturnsValidClosedHistory() throws {
        let fixture = try replayFixture(events: [
            (.transition, "running", t0),
            (.transition, "closed", t0.addingTimeInterval(60)),
        ])

        let result = try SessionReplay(summary: fixture.summary).replay(events: fixture.events, task: nil)

        #expect(result.session.state(at: t0.addingTimeInterval(60)) == .closed)
        #expect(result.session.transitions.map(\.state) == [.idle, .running, .closed])
    }

    @Test func testClosedRestorePreservesEveryPreCallProperty() throws {
        let (model, store) = try sentinelModel()
        let before = modelState(model)
        let closedID = UUID()
        try store.createSession(id: closedID, policyName: TimingPolicy.recoveryFirst.name, startedAt: t0.addingTimeInterval(100))
        try store.saveTask(
            sessionID: closedID, title: "Do not apply", firstAction: "Still do not apply", at: t0.addingTimeInterval(100))
        try store.appendEvent(sessionID: closedID, kind: .transition, payload: "running", at: t0.addingTimeInterval(100))
        try store.appendEvent(sessionID: closedID, kind: .transition, payload: "closed", at: t0.addingTimeInterval(101))
        try store.appendEvent(sessionID: closedID, kind: .thoughtParked, payload: "Do not apply", at: t0.addingTimeInterval(102))

        try model.restore()

        #expect(modelState(model) == before)
    }

    @Test func testUnknownTransitionRestoreFailureIsAtomic() throws {
        let (model, store) = try sentinelModel()
        let before = modelState(model)
        let invalidID = UUID()
        try store.createSession(id: invalidID, policyName: TimingPolicy.recoveryFirst.name, startedAt: t0.addingTimeInterval(100))
        try store.saveTask(
            sessionID: invalidID, title: "Do not apply", firstAction: "Still do not apply", at: t0.addingTimeInterval(100))
        try store.appendEvent(sessionID: invalidID, kind: .transition, payload: "running", at: t0.addingTimeInterval(100))
        try store.appendEvent(sessionID: invalidID, kind: .transition, payload: "teleported", at: t0.addingTimeInterval(101))
        try store.appendEvent(sessionID: invalidID, kind: .thoughtParked, payload: "Do not apply", at: t0.addingTimeInterval(102))

        #expect(replayError { try model.restore() } == .unknownTransitionPayload("teleported"))
        #expect(modelState(model) == before)
    }

    @Test func testMalformedAdjustmentRestoreFailureIsAtomic() throws {
        let (model, store) = try sentinelModel()
        let before = modelState(model)
        let invalidID = UUID()
        try store.createSession(id: invalidID, policyName: TimingPolicy.recoveryFirst.name, startedAt: t0.addingTimeInterval(100))
        try store.saveTask(
            sessionID: invalidID, title: "Do not apply", firstAction: "Still do not apply", at: t0.addingTimeInterval(100))
        try store.appendEvent(sessionID: invalidID, kind: .transition, payload: "running", at: t0.addingTimeInterval(100))
        try store.appendEvent(sessionID: invalidID, kind: .adjustment, payload: "sixty", at: t0.addingTimeInterval(101))
        try store.appendEvent(sessionID: invalidID, kind: .thoughtParked, payload: "Do not apply", at: t0.addingTimeInterval(102))

        #expect(replayError { try model.restore() } == .invalidAdjustmentPayload("sixty"))
        #expect(modelState(model) == before)
    }

    @Test func testUnknownTransitionRemainsExplicitInReview() throws {
        let store = try LocalStore(inMemory: true)
        let model = AppModel(store: store, clock: { self.t0 })
        try model.begin()
        let id = try #require(model.sessionID)
        try store.appendEvent(sessionID: id, kind: .transition, payload: "teleported", at: t0.addingTimeInterval(1))

        let timeline = try model.reviewTimeline()

        #expect(timeline.contains { $0.label == "Unknown state record: teleported" })
    }

    @Test func testAppModelHasOneCodecOwnedTransitionAppendSite() throws {
        let appModelURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/AppModel.swift")
        let source = try String(contentsOf: appModelURL, encoding: .utf8)
        let directAppendPattern = #"kind:\s*\.transition"#
        let directAppendCount = try NSRegularExpression(pattern: directAppendPattern)
            .numberOfMatches(in: source, range: NSRange(source.startIndex..., in: source))
        let helperBody = try #require(balancedBody(after: "func appendTransition", in: source))

        #expect(directAppendCount == 1)
        #expect(helperBody.contains("TransitionPayload.encode(state)"))
        #expect(helperBody.contains("kind: .transition"))
        #expect(
            helperBody.range(of: "TransitionPayload.encode(state)")!.lowerBound
                < helperBody.range(of: "kind: .transition")!.lowerBound)
        for payload in ["running", "held", "break", "closed"] {
            #expect(!source.contains("\"\(payload)\""), "AppModel contains bare durable transition payload \(payload)")
        }
    }

    private struct ReplayFixture {
        let summary: LocalStore.SessionSummary
        let sessionID: UUID
        let events: [StoredEvent]
    }

    private func replayFixture(
        policy: TimingPolicy = .classic,
        events: [(kind: StoredEventKind, payload: String, at: Date)]
    ) throws -> ReplayFixture {
        let store = try LocalStore(inMemory: true)
        let id = UUID()
        try store.createSession(id: id, policyName: policy.name, startedAt: t0)
        for event in events {
            try store.appendEvent(sessionID: id, kind: event.kind, payload: event.payload, at: event.at)
        }
        let summary = try #require(try store.latestSession())
        return ReplayFixture(
            summary: summary,
            sessionID: id,
            events: try store.events(sessionID: id))
    }

    private func sentinelModel() throws -> (AppModel, LocalStore) {
        let store = try LocalStore(inMemory: true)
        let model = AppModel(store: store, clock: { self.t0 })
        model.taskTitle = "Sentinel task"
        model.firstAction = "Sentinel action"
        model.policy = .flow
        try model.begin()
        try model.parkThought("Sentinel thought")
        return (model, store)
    }

    private struct ModelState: Equatable {
        let session: Session?
        let sessionID: UUID?
        let taskTitle: String
        let firstAction: String
        let parkedThoughts: [String]
        let policy: TimingPolicy
        let surface: Surface
    }

    private func modelState(_ model: AppModel) -> ModelState {
        ModelState(
            session: model.session,
            sessionID: model.sessionID,
            taskTitle: model.taskTitle,
            firstAction: model.firstAction,
            parkedThoughts: model.parkedThoughts,
            policy: model.policy,
            surface: model.surface)
    }

    private func replayError(_ operation: () throws -> Void) -> SessionReplayError? {
        do {
            try operation()
            return nil
        } catch {
            return error as? SessionReplayError
        }
    }

    private func balancedBody(after marker: String, in source: String) -> String? {
        guard let markerRange = source.range(of: marker),
            let opening = source[markerRange.upperBound...].firstIndex(of: "{")
        else { return nil }
        var depth = 0
        var cursor = opening
        while cursor < source.endIndex {
            if source[cursor] == "{" { depth += 1 }
            if source[cursor] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[source.index(after: opening)..<cursor])
                }
            }
            cursor = source.index(after: cursor)
        }
        return nil
    }
}
