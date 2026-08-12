import Foundation
import Testing

@testable import Praxmodoro
import PraxmodoroCore

/// Spec: add-session-settings "Settings scene" / "Autostart behaviour is the
/// user's choice" / "Sound cues, all optional" (tasks 4.1–4.3). Preferences
/// live on the injected defaults seam, exactly like the Motion pattern, and
/// never touch the session store.
@Suite struct PreferencesTests {
    private func scratchDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: Rhythm (task 4.1)

    @Test func testRhythmFactoryDefaultsArePromptFirstAndUnchangedDurations() {
        let rhythm = RhythmPreferences.load(from: scratchDefaults())
        #expect(rhythm == RhythmPreferences.factory)
        #expect(rhythm.blockEnd == .promptFirst)
        #expect(rhythm.autoReturn == false)
        #expect(rhythm.focusPresets.isEmpty)
        #expect(rhythm.breakPresets.isEmpty)
        #expect(rhythm.cadence == nil)
    }

    @Test func testRhythmRoundTripsThroughDefaults() {
        let defaults = scratchDefaults()
        var rhythm = RhythmPreferences.factory
        rhythm.focusPresets = [40 * 60, 50 * 60]
        rhythm.breakPresets = [8 * 60]
        rhythm.cadence = LongBreakCadence(everyBlocks: 4, length: 15 * 60)
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        rhythm.save(to: defaults)

        #expect(RhythmPreferences.load(from: defaults) == rhythm)
    }

    @Test func testRhythmSurvivesRelaunch() {
        let name = UUID().uuidString
        let defaults = scratchDefaults(name)
        var rhythm = RhythmPreferences.factory
        rhythm.blockEnd = .manual
        rhythm.save(to: defaults)

        // A fresh read over the same domain is what relaunch looks like.
        #expect(RhythmPreferences.load(from: defaults).blockEnd == .manual)
        defaults.removePersistentDomain(forName: name)
    }

    // MARK: Sound (task 4.2)

    @Test func testSoundFactoryDefaultsAreSilent() {
        let sound = SoundPreferences.load(from: scratchDefaults())
        #expect(sound == SoundPreferences.factory)
        #expect(sound.focusTick == false)
        #expect(sound.breakTick == false)
        #expect(sound.focusEndChime == false)
        #expect(sound.breakEndChime == false)
        #expect(sound.tickLoop == false)
    }

    @Test func testSoundRoundTripsThroughDefaults() {
        let defaults = scratchDefaults()
        var sound = SoundPreferences.factory
        sound.masterVolume = 0.4
        sound.focusEndChime = true
        sound.tickLoop = true
        sound.save(to: defaults)

        #expect(SoundPreferences.load(from: defaults) == sound)
    }

    // MARK: Malformed data never crashes, never writes back (task 4.3)

    @Test func testMalformedRhythmDataDecodesToFactory() {
        let defaults = scratchDefaults()
        defaults.set(Data("not json".utf8), forKey: RhythmPreferences.key)
        #expect(RhythmPreferences.load(from: defaults) == .factory)
        // Loading must not repair-write: the garbage stays until a real save.
        #expect(defaults.data(forKey: RhythmPreferences.key) == Data("not json".utf8))
    }

    @Test func testMalformedSoundDataDecodesToFactory() {
        let defaults = scratchDefaults()
        defaults.set("wrong type entirely", forKey: SoundPreferences.key)
        #expect(SoundPreferences.load(from: defaults) == .factory)
    }

    @Test func testVolumeClampsToSaneRange() {
        let defaults = scratchDefaults()
        var sound = SoundPreferences.factory
        sound.masterVolume = 7.5
        sound.save(to: defaults)
        #expect(SoundPreferences.load(from: defaults).masterVolume == 1.0)
    }
}
