import Foundation
import Testing

@testable import Praxmodoro
import PraxmodoroCore
import PraxmodoroStore

/// Spec: add-session-settings "Settings scene" (tasks 5.1–5.5). The scene is
/// asserted at state level plus the repo's source-scan idiom — UI automation
/// stays in the UI suite.
@MainActor
@Suite struct SettingsSceneTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func scratchDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func model(defaults: UserDefaults) throws -> AppModel {
        AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 }, defaults: defaults)
    }

    private func source(_ file: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PraxmodoroTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // app
            .appendingPathComponent("Sources").appendingPathComponent(file)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: 5.1 — the scene exists and has a keyboard path

    @Test func testSettingsSceneIsDeclared() throws {
        let app = try source("PraxmodoroApp.swift")
        #expect(app.contains("Settings {"), "no Settings scene in the app body")
        #expect(app.contains("SettingsSurface"), "the Settings scene must host SettingsSurface")
    }

    @Test func testSettingsHasAKeyboardPath() {
        #expect(KeyboardMap.all["settings"] == "⌘,")
    }

    @Test func testSettingsSurfaceCarriesBothPanes() {
        #expect(SettingsSurface.paneTitles == ["Rhythm", "Sound & Notifications"])
    }

    @Test func testChangingAPreferenceNeverTouchesTheSession() throws {
        let model = try model(defaults: scratchDefaults())
        try model.begin()
        let before = model.session

        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        model.setRhythm(rhythm)
        var sound = model.sound
        sound.focusEndChime = true
        model.setSound(sound)

        #expect(model.session == before, "preferences must not disturb a running session")
        #expect(model.surface == .focus)
    }

    // MARK: 5.2 — Rhythm pane binds the whole family, changes land on the seam

    @Test func testRhythmChangesLandOnTheSeamAndSurviveRelaunch() throws {
        let name = UUID().uuidString
        let defaults = scratchDefaults(name)
        let first = try model(defaults: defaults)
        var rhythm = first.rhythm
        rhythm.focusPresets = [40 * 60]
        rhythm.cadence = LongBreakCadence(everyBlocks: 4, length: 15 * 60)
        first.setRhythm(rhythm)

        let relaunched = try model(defaults: defaults)
        #expect(relaunched.rhythm == rhythm)
        defaults.removePersistentDomain(forName: name)
    }

    @Test func testRhythmPaneBindsEveryField() throws {
        let pane = try source("Surfaces/RhythmPane.swift")
        for field in ["focusPresets", "breakPresets", "cadence", "blockEnd", "autoReturn"] {
            #expect(pane.contains(field), "Rhythm pane does not bind \(field)")
        }
    }

    // MARK: 5.3 — the flow exemption is stated, not silently applied

    @Test func testFlowExemptionNoticeIsPresentAndGentle() throws {
        #expect(RhythmPane.flowExemptionNotice.contains("Flow"))
        #expect(RhythmPane.flowExemptionNotice.lowercased().contains("never"))
        let pane = try source("Surfaces/RhythmPane.swift")
        #expect(pane.contains("flowExemptionNotice"), "the notice must actually render")
    }

    // MARK: 5.4 — Sound & Notifications pane binds its whole family

    @Test func testSoundChangesLandOnTheSeam() throws {
        let name = UUID().uuidString
        let defaults = scratchDefaults(name)
        let first = try model(defaults: defaults)
        var sound = first.sound
        sound.masterVolume = 0.3
        sound.tickLoop = true
        first.setSound(sound)

        #expect(try model(defaults: defaults).sound == sound)
        defaults.removePersistentDomain(forName: name)
    }

    @Test func testNotificationChangesLandOnTheSeam() throws {
        let name = UUID().uuidString
        let defaults = scratchDefaults(name)
        let first = try model(defaults: defaults)
        var prefs = first.notifications
        prefs.blockEndEnabled = true
        prefs.blockEndText = "my own words"
        first.setNotifications(prefs)

        #expect(try model(defaults: defaults).notifications == prefs)
        defaults.removePersistentDomain(forName: name)
    }

    @Test func testSoundPaneBindsEveryField() throws {
        let pane = try source("Surfaces/SoundNotificationsPane.swift")
        for field in [
            "masterVolume", "focusTick", "breakTick", "focusEndChime", "breakEndChime",
            "tickLoop", "blockEndEnabled", "breakEndEnabled", "blockEndText", "breakEndText",
            "bringToFront",
        ] {
            #expect(pane.contains(field), "Sound & Notifications pane does not bind \(field)")
        }
    }

    // MARK: 5.5 — panes speak SurfacePalette only

    @Test func testPanesContainNoRawColorLiterals() throws {
        for file in ["Surfaces/RhythmPane.swift", "Surfaces/SoundNotificationsPane.swift", "Surfaces/SettingsSurface.swift"] {
            let text = try source(file)
            #expect(!text.contains("Color(red:"), "\(file) states a colour of its own")
            #expect(!text.contains("Color(hue:"), "\(file) states a colour of its own")
            #expect(!text.contains(".foregroundColor(.blue"), "\(file) states a colour of its own")
        }
    }
}
