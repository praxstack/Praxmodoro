import Foundation
import PraxmodoroCore
import PraxmodoroStore
import Testing

@testable import Praxmodoro

/// Spec: add-session-settings "Sound cues, all optional" (tasks 7.2–7.5).
/// The director is a transition listener behind a seam; these tests prove
/// silence-by-default, canonical-instant scheduling, no retro-fire, and
/// tick loops that follow state — all without touching AVFoundation.
@MainActor
@Suite struct SoundDirectorTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private final class Ticker {
        var now: Date
        init(_ start: Date) { now = start }
    }

    /// Records every request the director makes of the audio layer.
    private final class CueRecorder: SoundCueScheduling {
        var scheduled: [(cue: SoundCue, at: Date, volume: Double)] = []
        var pending: [(cue: SoundCue, at: Date, volume: Double)] = []
        var cancels = 0
        var expiredCancellations: [Date] = []
        var loops: [(cue: SoundCue, on: Bool, volume: Double)] = []

        func scheduleChime(_ cue: SoundCue, at instant: Date, volume: Double) {
            scheduled.append((cue, instant, volume))
            pending.append((cue, instant, volume))
        }

        func cancelScheduledChimes() {
            cancels += 1
            pending.removeAll()
        }

        func setChimeVolume(_ volume: Double) {
            pending = pending.map { ($0.cue, $0.at, volume) }
        }

        func cancelExpiredChimes(at now: Date) {
            expiredCancellations.append(now)
        }

        func setTickLoop(_ cue: SoundCue, running: Bool, volume: Double) {
            loops.append((cue, running, volume))
        }
    }

    private func scratchDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func source(_ file: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent(file)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func makeModel(
        _ mutate: (inout SoundPreferences) -> Void = { _ in }
    ) throws -> (AppModel, Ticker, CueRecorder) {
        let ticker = Ticker(t0)
        let recorder = CueRecorder()
        let model = AppModel(
            store: try LocalStore(inMemory: true), clock: { ticker.now },
            defaults: scratchDefaults(), soundScheduler: recorder)
        var sound = model.sound
        mutate(&sound)
        model.setSound(sound)
        model.policy = .classic
        return (model, ticker, recorder)
    }

    // MARK: 7.2 — explicit all-off configuration, provable

    @Test func testAllOffConfigurationNeverTouchesTheAudioLayer() throws {
        let (model, ticker, recorder) = try makeModel {
            $0.blockStart = false
            $0.focusEndChime = false
            $0.breakEndChime = false
        }
        try model.begin()
        ticker.now = t0.addingTimeInterval(5 * 60)
        try model.toggleHold()
        ticker.now = t0.addingTimeInterval(6 * 60)
        try model.toggleHold()
        model.forwardMinute()
        // Factory rhythm is prompt-first: the block completes into a held
        // offer, so the break path goes accept → end → close.
        ticker.now = t0.addingTimeInterval(30 * 60)
        try model.acceptBlockEndOffer()
        ticker.now = t0.addingTimeInterval(32 * 60)
        try model.endBreak()
        try model.closeSession()

        #expect(recorder.scheduled.isEmpty, "an all-off configuration must schedule nothing")
        #expect(recorder.loops.isEmpty, "an all-off configuration must loop nothing")
    }

    // MARK: 7.3 — chime at the canonical instant, once, never retro

    @Test func testChimeSchedulesAtTheCanonicalExpiryInstant() throws {
        let (model, _, recorder) = try makeModel { $0.focusEndChime = true }
        try model.begin()
        let focusEnds = recorder.scheduled.filter { $0.cue == .focusEnd }
        #expect(focusEnds.count == 1)
        #expect(focusEnds.first?.at == t0.addingTimeInterval(25 * 60))
    }

    @Test func testAdjustmentReschedulesTheChime() throws {
        let (model, ticker, recorder) = try makeModel { $0.focusEndChime = true }
        try model.begin()
        ticker.now = t0.addingTimeInterval(10 * 60)
        model.forwardMinute()
        #expect(recorder.cancels >= 1, "the stale chime must be cancelled")
        #expect(recorder.scheduled.last?.at == t0.addingTimeInterval(26 * 60))
    }

    @Test func testHoldCancelsAndResumeReschedules() throws {
        let (model, ticker, recorder) = try makeModel { $0.focusEndChime = true }
        try model.begin()
        ticker.now = t0.addingTimeInterval(10 * 60)
        try model.toggleHold()
        let cancelsAfterHold = recorder.cancels
        #expect(cancelsAfterHold >= 1)
        ticker.now = t0.addingTimeInterval(14 * 60)
        try model.toggleHold()
        #expect(recorder.scheduled.last?.at == t0.addingTimeInterval(29 * 60), "held time must push the chime out")
    }

    @Test func testNoRetroChimeAfterSleepingThroughExpiry() throws {
        let (model, ticker, recorder) = try makeModel { $0.focusEndChime = true }
        try model.begin()
        let atBegin = recorder.scheduled.count
        // Wake far past expiry; materialization must not fire a stale chime.
        // (Factory rhythm is prompt-first, so the block completed into a
        // held place — resuming is the first intent that lands on it.)
        ticker.now = t0.addingTimeInterval(50 * 60)
        try model.toggleHold()
        let later = recorder.scheduled.dropFirst(atBegin)
        #expect(
            later.allSatisfy { $0.at > ticker.now.addingTimeInterval(-1) },
            "a chime for an instant already past is noise, not information")
    }

    @Test func testChimeCarriesMasterVolume() throws {
        let (model, _, recorder) = try makeModel {
            $0.focusEndChime = true
            $0.masterVolume = 0.4
        }
        try model.begin()
        #expect(recorder.scheduled.first?.volume == 0.4)
    }

    @Test func testMasterVolumeChangeReschedulesChimeAndUpdatesActiveTick() throws {
        let (model, _, recorder) = try makeModel {
            $0.focusTick = true
            $0.tickLoop = true
        }
        try model.begin()
        let cancelsBefore = recorder.cancels
        #expect(Set(recorder.pending.map(\.cue)) == [.blockStart, .focusEnd])
        var sound = model.sound
        sound.masterVolume = 0.2

        model.setSound(sound)

        #expect(recorder.cancels == cancelsBefore)
        #expect(Set(recorder.pending.map(\.cue)) == [.blockStart, .focusEnd])
        #expect(recorder.pending.allSatisfy { $0.volume == 0.2 })
        #expect(recorder.loops.last?.cue == .focusTick)
        #expect(recorder.loops.last?.on == true)
        #expect(recorder.loops.last?.volume == 0.2)
    }

    @Test func testCadenceChangeReschedulesActiveBreakChime() throws {
        let (model, ticker, recorder) = try makeModel { $0.focusEndChime = false }
        try model.begin()
        ticker.now = t0.addingTimeInterval(26 * 60)
        try model.acceptBlockEndOffer()
        #expect(recorder.scheduled.last?.at == t0.addingTimeInterval(31 * 60))
        let cancelsBefore = recorder.cancels
        var rhythm = model.rhythm
        rhythm.cadence = LongBreakCadence(everyBlocks: 1, length: 10 * 60)

        model.setRhythm(rhythm)

        #expect(recorder.cancels == cancelsBefore + 1)
        #expect(recorder.scheduled.last?.cue == .breakEnd)
        #expect(recorder.scheduled.last?.at == t0.addingTimeInterval(36 * 60))
    }

    // MARK: 10.6 — block-start transition edges and previews

    @Test func testBlockStartFiresExactlyOnceForInitialBeginAndExplicitReturn() throws {
        let (model, ticker, recorder) = try makeModel {
            $0.focusEndChime = false
            $0.breakEndChime = false
        }

        try model.begin()
        #expect(recorder.scheduled.filter { $0.cue == .blockStart }.map(\.at) == [t0])

        ticker.now = t0.addingTimeInterval(60)
        try model.answer(.needBreak)
        ticker.now = t0.addingTimeInterval(120)
        try model.endBreak()
        #expect(
            recorder.scheduled.filter { $0.cue == .blockStart }.map(\.at)
                == [t0, t0.addingTimeInterval(120)])
    }

    @Test func testMaterializedAutoReturnFiresBlockStartExactlyOnce() throws {
        let (model, ticker, recorder) = try makeModel {
            $0.focusEndChime = false
            $0.breakEndChime = false
        }
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        model.setRhythm(rhythm)

        try model.begin()
        ticker.now = t0.addingTimeInterval(31 * 60)
        try model.toggleHold()
        try model.toggleHold()

        #expect(
            recorder.scheduled.filter { $0.cue == .blockStart }.map(\.at)
                == [t0, t0.addingTimeInterval(30 * 60)])
    }

    @Test func testHoldResumeAndRestoreNeverFireBlockStart() throws {
        let defaults = scratchDefaults()
        let store = try LocalStore(inMemory: true)
        let ticker = Ticker(t0)
        let firstRecorder = CueRecorder()
        let model = AppModel(
            store: store, clock: { ticker.now }, defaults: defaults,
            soundScheduler: firstRecorder)
        model.policy = .classic
        try model.begin()
        ticker.now = t0.addingTimeInterval(60)
        try model.toggleHold()
        ticker.now = t0.addingTimeInterval(120)
        try model.toggleHold()
        #expect(firstRecorder.scheduled.filter { $0.cue == .blockStart }.count == 1)

        let restoredRecorder = CueRecorder()
        let restored = AppModel(
            store: store, clock: { ticker.now }, defaults: defaults,
            soundScheduler: restoredRecorder)
        try restored.restore()
        #expect(restoredRecorder.scheduled.allSatisfy { $0.cue != .blockStart })
    }

    @Test(arguments: SoundCue.allCases)
    func testEveryCuePreviewsWithoutASession(_ cue: SoundCue) throws {
        let (model, _, recorder) = try makeModel { $0.masterVolume = 0.37 }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let soundBefore = try encoder.encode(model.sound)
        let rhythmBefore = try encoder.encode(model.rhythm)
        let notificationsBefore = try encoder.encode(model.notifications)

        model.previewSound(cue)

        let request = try #require(recorder.scheduled.last)
        #expect(request.cue == cue)
        #expect(request.at == t0)
        #expect(request.volume == 0.37)
        #expect(model.session == nil)
        #expect(try encoder.encode(model.sound) == soundBefore)
        #expect(try encoder.encode(model.rhythm) == rhythmBefore)
        #expect(try encoder.encode(model.notifications) == notificationsBefore)
    }

    // MARK: 7.4 — tick loop follows state, no Timer anywhere

    @Test func testTickLoopFollowsRunningState() throws {
        let (model, ticker, recorder) = try makeModel {
            $0.focusTick = true
            $0.tickLoop = true
        }
        try model.begin()
        #expect(recorder.loops.last?.cue == .focusTick)
        #expect(recorder.loops.last?.on == true)
        ticker.now = t0.addingTimeInterval(5 * 60)
        try model.toggleHold()
        #expect(recorder.loops.last?.on == false, "holding must stop the tick")
        ticker.now = t0.addingTimeInterval(6 * 60)
        try model.toggleHold()
        #expect(recorder.loops.last?.on == true)
        try model.closeSession()
        #expect(recorder.loops.last?.on == false, "closing must stop the tick")
    }

    @Test func testBreakTickIsItsOwnToggle() throws {
        let (model, ticker, recorder) = try makeModel {
            $0.breakTick = true
            $0.tickLoop = true
        }
        try model.begin()
        #expect(
            !recorder.loops.contains { $0.cue == .focusTick && $0.on },
            "focus tick stays off unless asked for")
        ticker.now = t0.addingTimeInterval(26 * 60)
        try model.acceptBlockEndOffer()
        #expect(recorder.loops.last?.cue == .breakTick)
        #expect(recorder.loops.last?.on == true)
    }

    @Test func testDisablingSoundMidSessionSilencesEverything() throws {
        let (model, _, recorder) = try makeModel {
            $0.focusTick = true
            $0.tickLoop = true
            $0.focusEndChime = true
        }
        try model.begin()
        var allOff = SoundPreferences.factory
        allOff.blockStart = false
        allOff.focusEndChime = false
        allOff.breakEndChime = false
        model.setSound(allOff)
        #expect(recorder.loops.last?.on == false)
        #expect(recorder.cancels >= 1, "the pending chime must be cancelled with the setting")
    }

    // MARK: 7.5 — the production player fails silent, never fatal

    @Test func testMissingResourceNeverThrows() {
        // A player over a resource that does not exist must become inert,
        // not a crash and not an error surfaced to the session.
        let player = AudioCueScheduler(resourceLookup: { _ in nil })
        player.scheduleChime(.focusEnd, at: Date.distantFuture, volume: 1)
        player.setTickLoop(.focusTick, running: true, volume: 1)
        player.cancelScheduledChimes()
        #expect(Bool(true), "reaching here without a crash is the assertion")
    }

    // MARK: 10.9 — pending-player retention and wake cancellation

    @Test func testOrdinaryChimeRetentionKeepsPlayingOrFutureEntriesOnly() {
        #expect(shouldRetainChime(scheduledAt: t0.addingTimeInterval(1), now: t0, isPlaying: false))
        #expect(shouldRetainChime(scheduledAt: t0, now: t0, isPlaying: true))
        #expect(!shouldRetainChime(scheduledAt: t0.addingTimeInterval(-1), now: t0, isPlaying: false))
    }

    @Test func testWakeCancellationRemovesEveryExpiredPlayerAndKeepsFutureStoppedPlayer() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Sounds/chime-focus-end.wav")
        let scheduler = AudioCueScheduler(resourceLookup: { _ in url }, clock: { self.t0 })

        let future = t0.addingTimeInterval(60)
        scheduler.scheduleChime(.focusEnd, at: future, volume: 0)
        let futurePlayer = try #require(scheduler.pendingChimes.last?.player)
        futurePlayer.stop()

        let expired = t0.addingTimeInterval(-60)
        scheduler.scheduleChime(.focusEnd, at: expired, volume: 0)
        let expiredPlaying = try #require(scheduler.pendingChimes.last?.player)
        #expect(expiredPlaying.isPlaying)

        scheduler.scheduleChime(.focusEnd, at: expired, volume: 0)
        let expiredStopped = try #require(scheduler.pendingChimes.last?.player)
        expiredStopped.stop()
        #expect(scheduler.pendingChimes.count == 3)

        scheduler.setChimeVolume(0.25)
        #expect(scheduler.pendingChimes.allSatisfy { abs(Double($0.player.volume) - 0.25) < 0.000_001 })

        scheduler.cancelExpiredChimes(at: t0)

        #expect(scheduler.pendingChimes.map(\.scheduledAt) == [future])
        #expect(scheduler.pendingChimes.first?.player === futurePlayer)
        #expect(!expiredPlaying.isPlaying)
        #expect(!expiredStopped.isPlaying)
    }

    @Test func testSystemWakeReadsInjectedClockOnceAndCancelsAtThatInstant() {
        final class CountingClock {
            var reads = 0
            func read() -> Date {
                reads += 1
                return Date(timeIntervalSinceReferenceDate: 900_000_000)
            }
        }
        let clock = CountingClock()
        let recorder = CueRecorder()
        let model = AppModel(
            store: nil, clock: { clock.read() }, defaults: scratchDefaults(),
            soundScheduler: recorder)
        let before = clock.reads

        model.handleSystemWake()

        #expect(clock.reads == before + 1)
        #expect(recorder.expiredCancellations == [Date(timeIntervalSinceReferenceDate: 900_000_000)])
    }

    @Test func testAppWakeWiringCancelsOnlyAndLeavesResyncToTheNextDateEdge() throws {
        let app = try source("PraxmodoroApp.swift").filter { !$0.isWhitespace }
        #expect(app.contains("publisher(for:NSWorkspace.didWakeNotification)"))
        #expect(app.contains("{_inmodel.handleSystemWake()}"))

        let model = try source("AppModel.swift").filter { !$0.isWhitespace }
        #expect(model.contains("funchandleSystemWake(){soundScheduler.cancelExpiredChimes(at:clock())}"))
    }

    @Test func testBundledResourcesActuallyExist() throws {
        for cue in SoundCue.allCases {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/Sounds").appendingPathComponent(cue.resourceName)
            #expect(FileManager.default.fileExists(atPath: url.path), "missing bundled asset \(cue.resourceName)")
        }
    }

    /// The source tree had the files while the built product did not —
    /// project.yml used a key xcodegen silently ignores, and the scan above
    /// was blind to it (found live: an installed build with no sounds).
    /// These tests run hosted in the app, so Bundle.main IS the built
    /// product; this closes the gap at the artifact level.
    @Test func testBundledResourcesResolveInTheBuiltProduct() {
        for cue in SoundCue.allCases {
            let resolved =
                Bundle.main.url(forResource: cue.resourceName, withExtension: nil, subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: cue.resourceName, withExtension: nil)
            #expect(resolved != nil, "\(cue.resourceName) missing from the built app bundle")
        }
    }
}
