import Foundation
import PraxmodoroCore
import PraxmodoroStore
import Testing

@testable import Praxmodoro

/// Fixes for the independent validator's findings on add-session-settings
/// (report 2026-08-13): each test names the finding it closes.
@MainActor
@Suite struct ValidatorFindingsTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private final class Ticker {
        var now: Date
        init(_ start: Date) { now = start }
    }

    private final class CueRecorder: SoundCueScheduling {
        var scheduled: [(cue: SoundCue, at: Date, volume: Double)] = []
        var cancels = 0
        var loops: [(cue: SoundCue, on: Bool)] = []

        func scheduleChime(_ cue: SoundCue, at instant: Date, volume: Double) {
            scheduled.append((cue, instant, volume))
        }

        func cancelScheduledChimes() { cancels += 1 }

        func setTickLoop(_ cue: SoundCue, running: Bool, volume: Double) {
            loops.append((cue, running))
        }
    }

    private final class NotificationRecorder: NotificationScheduling {
        var scheduled: [LocalNotificationRequest] = []
        var cancels = 0
        var availabilityChecks = 0
        var availability = NotificationAvailability.available

        func schedule(_ request: LocalNotificationRequest) { scheduled.append(request) }
        func cancelPending() { cancels += 1 }
        func checkAvailability(_ report: @escaping @MainActor (NotificationAvailability) -> Void) {
            availabilityChecks += 1
            let value = availability
            Task { @MainActor in report(value) }
        }
    }

    private func scratchDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeModel() throws -> (AppModel, Ticker, CueRecorder, NotificationRecorder) {
        let ticker = Ticker(t0)
        let cues = CueRecorder()
        let notifs = NotificationRecorder()
        let model = AppModel(
            store: try LocalStore(inMemory: true), clock: { ticker.now },
            defaults: scratchDefaults(), soundScheduler: cues, notificationScheduler: notifs)
        return (model, ticker, cues, notifs)
    }

    private func source(_ file: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent(file)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: Finding 1 (blocker) — custom presets are reachable end-to-end

    @Test func testCustomPresetsAppearAmongPolicies() throws {
        let (model, _, _, _) = try makeModel()
        var rhythm = model.rhythm
        rhythm.focusPresets = [40 * 60]
        rhythm.breakPresets = [8 * 60]
        model.setRhythm(rhythm)

        let custom = model.availablePolicies.first { $0.focus == TimeInterval(40 * 60) }
        let policy = try #require(custom, "a created preset must be offered at initiation")
        #expect(policy.suggestedBreak == TimeInterval(8 * 60))
    }

    @Test func testBeginningWithACustomPresetDrivesTheSession() throws {
        let (model, ticker, _, _) = try makeModel()
        var rhythm = model.rhythm
        rhythm.focusPresets = [40 * 60]
        model.setRhythm(rhythm)
        model.taskTitle = "t"
        model.policy = try #require(model.availablePolicies.first { $0.focus == TimeInterval(40 * 60) })
        try model.begin()
        ticker.now = t0.addingTimeInterval(10 * 60)
        #expect(model.snapshot(at: ticker.now).remaining == TimeInterval(30 * 60))
    }

    @Test func testInitiateSurfaceOffersThePolicies() throws {
        let surface = try source("Surfaces/InitiateSurface.swift")
        #expect(surface.contains("availablePolicies"), "initiation must offer the model's policies, not a hardcoded four")
    }

    // MARK: Finding 2 (blocker) — authorization is wired to first enable

    @Test func testEnablingANotificationChecksAvailability() throws {
        let (model, _, _, notifs) = try makeModel()
        let before = notifs.availabilityChecks
        var prefs = model.notifications
        prefs.blockEndEnabled = true
        model.setNotifications(prefs)
        #expect(notifs.availabilityChecks > before, "the first enable must trigger the authorization path")
    }

    @Test func testFactoryInitNeverPromptsForAuthorization() throws {
        let (_, _, _, notifs) = try makeModel()
        #expect(notifs.availabilityChecks == 0, "a fresh install with nothing enabled must not prompt")
    }

    @Test func testInitRefreshesWhenAlreadyEnabled() throws {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        var prefs = NotificationPreferences.factory
        prefs.blockEndEnabled = true
        prefs.save(to: defaults)

        let notifs = NotificationRecorder()
        _ = AppModel(
            store: try LocalStore(inMemory: true), clock: { self.t0 },
            defaults: defaults, soundScheduler: InertCues(), notificationScheduler: notifs)
        #expect(notifs.availabilityChecks == 1, "a returning user's denial state must refresh at launch")
        defaults.removePersistentDomain(forName: name)
    }

    // MARK: Finding 3 (major) — derived transitions sync presentation

    @Test func testDerivedHoldStopsTheTick() throws {
        let (model, ticker, cues, _) = try makeModel()
        var sound = model.sound
        sound.focusTick = true
        sound.tickLoop = true
        model.setSound(sound)
        model.policy = .classic
        try model.begin()
        #expect(cues.loops.last?.on == true)
        // Prompt-first (factory) expiry: a derived hold, no intent anywhere.
        ticker.now = t0.addingTimeInterval(26 * 60)
        model.syncPresentation(at: ticker.now)
        #expect(cues.loops.last?.on == false, "the tick must stop within a period of the derived hold")
    }

    @Test func testDerivedBreakHandsTickOverAndAnchorsBreakChime() throws {
        let (model, ticker, cues, _) = try makeModel()
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        model.setRhythm(rhythm)
        var sound = model.sound
        sound.focusTick = true
        sound.breakTick = true
        sound.tickLoop = true
        sound.breakEndChime = true
        model.setSound(sound)
        model.policy = .classic
        try model.begin()
        ticker.now = t0.addingTimeInterval(26 * 60)
        model.syncPresentation(at: ticker.now)
        #expect(cues.loops.contains { $0.cue == .focusTick && !$0.on }, "focus tick must yield")
        #expect(cues.loops.last?.cue == .breakTick)
        #expect(cues.loops.last?.on == true)
        #expect(cues.scheduled.last?.cue == .breakEnd)
        #expect(cues.scheduled.last?.at == t0.addingTimeInterval(30 * 60), "break-end chime anchors on the derived break's end")
    }

    @Test func testCoreBreakEndAgreesWithSoundNotificationAndMaterializedReturn() throws {
        let (model, ticker, cues, notifications) = try makeModel()
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        rhythm.cadence = LongBreakCadence(everyBlocks: 1, length: 10 * 60)
        model.setRhythm(rhythm)
        var sound = model.sound
        sound.breakEndChime = true
        model.setSound(sound)
        var notificationPreferences = model.notifications
        notificationPreferences.breakEndEnabled = true
        model.setNotifications(notificationPreferences)
        model.policy = .classic
        try model.begin()

        ticker.now = t0.addingTimeInterval(26 * 60)
        model.syncPresentation(at: ticker.now)
        let canonicalBreakEnd = t0.addingTimeInterval(35 * 60)
        #expect(cues.scheduled.last?.at == canonicalBreakEnd)
        #expect(notifications.scheduled.last?.at == canonicalBreakEnd)

        ticker.now = canonicalBreakEnd.addingTimeInterval(1)
        try model.toggleHold()
        #expect(
            model.session?.transitions.contains {
                $0.state == .running && $0.at == canonicalBreakEnd
            } == true)
    }

    @Test func testAppModelUsesOnlyTheCoreBreakEndAndProcessBoundary() throws {
        let compact = try source("AppModel.swift").filter { !$0.isWhitespace }
        #expect(compact.components(separatedBy: "breakEndInstant(cadence:rhythm.cadence)").count - 1 == 2)
        #expect(!compact.contains("breakStart.addingTimeInterval"))
        #expect(compact.contains("privateletliveObservationStartedAt:Date"))
        #expect(
            compact.contains(
                "autoReturn:rhythm.autoReturn,autoReturnAfter:rhythm.autoReturn?liveObservationStartedAt:nil"))
        #expect(compact.contains("autoReturn:false,autoReturnAfter:nil"))
    }
    @Test func testRoutingHookSyncsPresentation() throws {
        let app = try source("PraxmodoroApp.swift")
        #expect(app.contains("syncPresentation"), "the render loop must hand derived phase changes to the model")
    }

    // MARK: Finding 5 (major) — promotion never raises the return overlay

    @Test func testPromotionDoesNotGreetLikeAReturn() throws {
        let (model, ticker, _, _) = try makeModel()
        model.policy = .gentleStart
        model.taskTitle = "t"
        try model.begin()
        ticker.now = t0.addingTimeInterval(6 * 60)
        try model.toggleHold()
        #expect(model.returnPending == false, "a promotion is seamless, not a comeback")
    }

    @Test func testMaterializedReturnFromBreakStillGreets() throws {
        let (model, ticker, _, _) = try makeModel()
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        model.setRhythm(rhythm)
        model.policy = .classic
        try model.begin()
        ticker.now = t0.addingTimeInterval(31 * 60)
        try model.toggleHold()
        #expect(model.returnPending, "a materialized return from a break greets like any other return")
    }

    // MARK: Finding 7 (major) — the long break is actually suggested

    @Test func testLongBreakSuggestionSurfacesWhenDue() throws {
        let (model, ticker, _, _) = try makeModel()
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.cadence = LongBreakCadence(everyBlocks: 1, length: 15 * 60)
        model.setRhythm(rhythm)
        model.policy = .classic
        try model.begin()
        ticker.now = t0.addingTimeInterval(26 * 60)
        let minutes = try #require(model.longBreakMinutesDue(at: ticker.now))
        #expect(minutes == 15)
        let surface = try source("Surfaces/BreakSurface.swift")
        #expect(surface.contains("longBreakMinutesDue"), "the break surface must present the suggestion")
    }

    @Test func testNoCadenceMeansNoLongBreakLine() throws {
        let (model, ticker, _, _) = try makeModel()
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        model.setRhythm(rhythm)
        model.policy = .classic
        try model.begin()
        ticker.now = t0.addingTimeInterval(26 * 60)
        #expect(model.longBreakMinutesDue(at: ticker.now) == nil)
    }

    // MARK: Finding 9 (minor) — denied means visibly unavailable controls

    @Test func testPaneDisablesControlsWhenDenied() throws {
        let pane = try source("Surfaces/SoundNotificationsPane.swift")
        #expect(pane.contains(".disabled(model.notificationsUnavailable)"),
                "denied permission must render the controls plainly unavailable, not just captioned")
    }
}

private struct InertCues: SoundCueScheduling {
    func scheduleChime(_ cue: SoundCue, at instant: Date, volume: Double) {}
    func cancelScheduledChimes() {}
    func setTickLoop(_ cue: SoundCue, running: Bool, volume: Double) {}
}
