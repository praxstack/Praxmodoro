import AppKit
import Foundation
import PraxmodoroCore
import PraxmodoroStore
import Testing

@testable import Praxmodoro

/// Background observation (change: fix-menubar-launch-hang). With every
/// window closed the model itself asks to be woken at the next instant the
/// reconciled engine can change; nothing re-renders the menu-bar label to
/// keep date edges alive.
@MainActor
@Suite struct ScheduledObservationTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private final class Ticker {
        var now: Date
        init(_ start: Date) { now = start }
    }

    /// Records each requested wake and holds the latest fire hook, so a test
    /// can stand in for the run loop at an instant of its choosing.
    private final class WakeRecorder: ObservationScheduling {
        var requested: [Date] = []
        var cancels = 0
        private var fire: (@MainActor () -> Void)?

        var pending: Date? { fire == nil ? nil : requested.last }

        func schedule(at instant: Date, _ fire: @escaping @MainActor () -> Void) {
            requested.append(instant)
            self.fire = fire
        }

        func cancel() {
            cancels += 1
            fire = nil
        }

        func firePending() {
            let hook = fire
            fire = nil
            hook?()
        }
    }

    private final class SilentCues: SoundCueScheduling {
        var scheduled: [(cue: SoundCue, at: Date)] = []
        func scheduleChime(_ cue: SoundCue, at instant: Date, volume: Double) { scheduled.append((cue, instant)) }
        func cancelScheduledChime(_ cue: SoundCue, at instant: Date) {}
        func setChimeVolume(_ volume: Double) {}
        func cancelExpiredChimes(at now: Date) {}
        func setTickLoop(_ cue: SoundCue, running: Bool, volume: Double) {}
    }

    private final class SilentNotifications: NotificationScheduling {
        func schedule(_ request: LocalNotificationRequest) {}
        func cancelPending() {}
        func checkAvailability(_ report: @escaping @MainActor (NotificationAvailability) -> Void) {}
    }

    private func scratchDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeModel() throws -> (AppModel, Ticker, WakeRecorder, SilentCues) {
        let ticker = Ticker(t0)
        let wakes = WakeRecorder()
        let cues = SilentCues()
        let model = AppModel(
            store: try LocalStore(inMemory: true), clock: { ticker.now },
            defaults: scratchDefaults(), soundScheduler: cues,
            notificationScheduler: SilentNotifications(), observationScheduler: wakes)
        return (model, ticker, wakes, cues)
    }

    private func source(_ file: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent(file)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func testNoSessionRequestsNoWake() throws {
        let (_, _, wakes, _) = try makeModel()
        #expect(wakes.requested.isEmpty)
    }

    @Test func testBeginAsksForAWakeAtTheCanonicalExpiry() throws {
        let (model, _, wakes, _) = try makeModel()
        model.policy = .classic
        try model.begin()
        #expect(wakes.pending == t0.addingTimeInterval(25 * 60))
    }

    @Test func testRepeatedObservationAtTheSameEdgeDoesNotReArm() throws {
        let (model, ticker, wakes, _) = try makeModel()
        model.policy = .classic
        try model.begin()
        let armed = wakes.requested.count
        ticker.now = t0.addingTimeInterval(60)
        try model.observeDerivedPhase(at: ticker.now)
        try model.observeDerivedPhase(at: ticker.now.addingTimeInterval(1))
        #expect(wakes.requested.count == armed)
    }

    /// The whole live cycle with no window and no TimelineView: each wake
    /// materializes the canonical transition and arms the next edge.
    @Test func testWakesCarryAWholeCycleWithEveryWindowClosed() throws {
        let (model, ticker, wakes, cues) = try makeModel()
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        model.setRhythm(rhythm)
        model.policy = .classic
        try model.begin()

        let expiry = t0.addingTimeInterval(25 * 60)
        let breakEnd = t0.addingTimeInterval(30 * 60)
        #expect(wakes.pending == expiry)

        ticker.now = expiry
        wakes.firePending()
        #expect(model.session?.transitions.last == TransitionRecord(intent: nil, state: .onBreak, at: expiry))
        #expect(wakes.pending == breakEnd)

        ticker.now = breakEnd
        wakes.firePending()
        #expect(model.session?.transitions.last == TransitionRecord(intent: nil, state: .running, at: breakEnd))
        #expect(model.returnPending)
        #expect(cues.scheduled.filter { $0.cue == .blockStart }.map(\.at) == [t0, breakEnd])
        #expect(wakes.pending == breakEnd.addingTimeInterval(25 * 60))
    }

    /// A wake that lands late (the Mac slept through the edge) backdates
    /// every transition to its canonical instant, never to wake time.
    @Test func testALateWakeBackdatesToCanonicalInstants() throws {
        let (model, ticker, wakes, cues) = try makeModel()
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        model.setRhythm(rhythm)
        model.policy = .classic
        try model.begin()

        ticker.now = t0.addingTimeInterval(31 * 60)
        model.handleSystemWake()
        wakes.firePending()

        // The return happened while asleep; its block-start is not replayed.
        #expect(cues.scheduled.filter { $0.cue == .blockStart }.map(\.at) == [t0])
        let transitions = try #require(model.session?.transitions)
        #expect(transitions.contains(TransitionRecord(intent: nil, state: .onBreak, at: t0.addingTimeInterval(25 * 60))))
        #expect(transitions.contains(TransitionRecord(intent: nil, state: .running, at: t0.addingTimeInterval(30 * 60))))
        #expect(wakes.pending == t0.addingTimeInterval(55 * 60))
    }

    @Test func testAHeldBlockStopsAskingForWakes() throws {
        let (model, ticker, wakes, _) = try makeModel()
        model.policy = .classic
        try model.begin()
        ticker.now = t0.addingTimeInterval(60)
        try model.toggleHold()
        #expect(wakes.pending == nil)
        #expect(wakes.cancels >= 1)
    }

    // MARK: Production scheduler

    @Test func testWallClockSchedulerFiresAnInstantAlreadyPast() async {
        let scheduler = EdgeObservationScheduler(wakeCenter: NotificationCenter(), clockCenter: NotificationCenter())
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            scheduler.schedule(at: .distantPast) { done.resume() }
        }
    }

    @Test func testWallClockSchedulerReArmsOnWakeAndClockChangeAndForgetsWhenCancelled() {
        let wake = NotificationCenter()
        let clock = NotificationCenter()
        let scheduler = EdgeObservationScheduler(wakeCenter: wake, clockCenter: clock)
        scheduler.schedule(at: .distantFuture) {}
        #expect(scheduler.armCount == 1)

        wake.post(name: NSWorkspace.didWakeNotification, object: nil)
        #expect(scheduler.armCount == 2)
        clock.post(name: .NSSystemClockDidChange, object: nil)
        #expect(scheduler.armCount == 3)

        scheduler.cancel()
        wake.post(name: NSWorkspace.didWakeNotification, object: nil)
        clock.post(name: .NSSystemClockDidChange, object: nil)
        #expect(scheduler.armCount == 3)
    }

    /// End to end on the real run loop and the real wall clock, with no
    /// window, popover, or TimelineView anywhere: a two-second block expires
    /// into a two-second break and auto-returns, each edge recorded by the
    /// production scheduler alone.
    @Test func testLiveSchedulerCarriesACycleWithNoViewMounted() async throws {
        let model = AppModel(
            store: try LocalStore(inMemory: true), defaults: scratchDefaults(),
            soundScheduler: SilentCues(), notificationScheduler: SilentNotifications(),
            observationScheduler: EdgeObservationScheduler(
                wakeCenter: NotificationCenter(), clockCenter: NotificationCenter()))
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        model.setRhythm(rhythm)
        model.policy = .custom(arrival: nil, focus: 2, suggestedBreak: 2)
        try model.begin()
        let start = try #require(model.session?.transitions.first?.at)

        var waited = 0
        while !model.returnPending && waited < 100 {
            try await Task.sleep(for: .milliseconds(100))
            waited += 1
        }

        #expect(model.returnPending)
        let states = try #require(model.session?.transitions).map { ($0.state, $0.at) }
        #expect(states.contains { $0 == (.onBreak, start.addingTimeInterval(2)) })
        #expect(states.contains { $0 == (.running, start.addingTimeInterval(4)) })
    }

    // MARK: Wiring

    /// Regression guard for the launch hang: a TimelineView in the status
    /// item's label re-rendered the button every second and looped the main
    /// thread in MenuBarExtra's button update on macOS 27.
    @Test func testMenuBarLabelHostsNoTimeline() throws {
        let app = try source("PraxmodoroApp.swift")
        let label = try #require(app.range(of: "} label: {"))
        let afterLabel = app[label.upperBound...]
        let end = try #require(afterLabel.range(of: ".menuBarExtraStyle"))
        // Code only: the label's comment explains the hang by name.
        let body = afterLabel[..<end.lowerBound]
            .split(separator: "\n")
            .map { line in line.range(of: "//").map { line[..<$0.lowerBound] } ?? line }
            .joined(separator: "\n")
        #expect(!body.contains("TimelineView"))
        #expect(!body.contains("observeDerivedPhase"))
        #expect(body.contains("model.handleSystemWake()"))
    }

    @Test func testAppInjectsTheEdgeSchedulerOnEveryLaunchPath() throws {
        let app = try source("PraxmodoroApp.swift")
        let constructions = app.components(separatedBy: "AppModel(").count - 1
        let injected = app.components(separatedBy: "observationScheduler: EdgeObservationScheduler()").count - 1
        #expect(constructions == 2)
        #expect(injected == constructions)
    }
}
