import Foundation
import Testing

@testable import Praxmodoro
import PraxmodoroCore
import PraxmodoroStore

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
        var cancels = 0
        var loops: [(cue: SoundCue, on: Bool)] = []

        func scheduleChime(_ cue: SoundCue, at instant: Date, volume: Double) {
            scheduled.append((cue, instant, volume))
        }

        func cancelScheduledChimes() {
            cancels += 1
        }

        func setTickLoop(_ cue: SoundCue, running: Bool, volume: Double) {
            loops.append((cue, running))
        }
    }

    private func scratchDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
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

    // MARK: 7.2 — factory silence, provable

    @Test func testFactoryDefaultsNeverTouchTheAudioLayer() throws {
        let (model, ticker, recorder) = try makeModel()
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

        #expect(recorder.scheduled.isEmpty, "factory settings must schedule nothing")
        #expect(recorder.loops.isEmpty, "factory settings must loop nothing")
    }

    // MARK: 7.3 — chime at the canonical instant, once, never retro

    @Test func testChimeSchedulesAtTheCanonicalExpiryInstant() throws {
        let (model, _, recorder) = try makeModel { $0.focusEndChime = true }
        try model.begin()
        #expect(recorder.scheduled.count == 1)
        #expect(recorder.scheduled.first?.cue == .focusEnd)
        #expect(recorder.scheduled.first?.at == t0.addingTimeInterval(25 * 60))
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
        #expect(later.allSatisfy { $0.at > ticker.now.addingTimeInterval(-1) },
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
        #expect(!recorder.loops.contains { $0.cue == .focusTick && $0.on },
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
        model.setSound(.factory)
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

    @Test func testBundledResourcesActuallyExist() throws {
        for cue in [SoundCue.focusTick, .breakTick, .focusEnd, .breakEnd] {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/Sounds").appendingPathComponent(cue.resourceName)
            #expect(FileManager.default.fileExists(atPath: url.path), "missing bundled asset \(cue.resourceName)")
        }
    }
}
