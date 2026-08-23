import Foundation
import PraxmodoroCore
import PraxmodoroStore
import SwiftUI
import Testing

@testable import Praxmodoro

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

    private static func codeOnly(_ source: String) -> String {
        enum Mode { case code, lineComment, blockComment, string }
        let input = Array(source.utf8)
        var output = input
        var mode = Mode.code
        var blockDepth = 0
        var index = 0

        func blank(_ position: Int) {
            if output[position] != 10 && output[position] != 13 { output[position] = 32 }
        }

        while index < input.count {
            let byte = input[index]
            let next = index + 1 < input.count ? input[index + 1] : 0
            switch mode {
            case .code:
                if byte == 47 && next == 47 {
                    blank(index); blank(index + 1); index += 2; mode = .lineComment
                } else if byte == 47 && next == 42 {
                    blank(index); blank(index + 1); index += 2; blockDepth = 1; mode = .blockComment
                } else if byte == 34 {
                    blank(index); index += 1; mode = .string
                } else {
                    index += 1
                }
            case .lineComment:
                blank(index); index += 1
                if byte == 10 { mode = .code }
            case .blockComment:
                if byte == 47 && next == 42 {
                    blank(index); blank(index + 1); index += 2; blockDepth += 1
                } else if byte == 42 && next == 47 {
                    blank(index); blank(index + 1); index += 2; blockDepth -= 1
                    if blockDepth == 0 { mode = .code }
                } else {
                    blank(index); index += 1
                }
            case .string:
                blank(index)
                if byte == 92 && index + 1 < input.count {
                    blank(index + 1); index += 2
                } else {
                    index += 1
                    if byte == 34 { mode = .code }
                }
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    private static func balancedBody(after marker: String, in code: String) -> String? {
        guard let markerRange = code.range(of: marker),
            let opening = code[markerRange.upperBound...].firstIndex(of: "{")
        else { return nil }
        var depth = 0
        var cursor = opening
        while cursor < code.endIndex {
            if code[cursor] == "{" { depth += 1 }
            if code[cursor] == "}" {
                depth -= 1
                if depth == 0 { return String(code[code.index(after: opening)..<cursor]) }
            }
            cursor = code.index(after: cursor)
        }
        return nil
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

    @Test func testRhythmPaneOffersEditAndRemoveForBothPresetFamilies() throws {
        let pane = try source("Surfaces/RhythmPane.swift")
        #expect(pane.contains("presetList(keyPath: \\.focusPresets, drafts: $focusDrafts)"))
        #expect(pane.contains("presetList(keyPath: \\.breakPresets, drafts: $breakDrafts)"))
        #expect(pane.contains("TextField(\"Preset minutes\""))
        #expect(pane.contains("Button(\"Save\")"))
        #expect(pane.contains("Button(\"Remove\")"))
        #expect(pane.contains("RhythmPreferences.presetHelp"))
    }

    @Test func testAvailablePoliciesContainEveryUniquePresetPairAndFallbacks() throws {
        let defaults = scratchDefaults()
        let app = try model(defaults: defaults)
        var rhythm = app.rhythm
        rhythm.focusPresets = [40 * 60, 50 * 60]
        rhythm.breakPresets = [8 * 60, 10 * 60]
        app.setRhythm(rhythm)

        let custom = app.availablePolicies.filter { $0.name.hasPrefix("custom:") }
        let expectedPairs = Set([
            TimingPolicy.custom(arrival: nil, focus: 40 * 60, suggestedBreak: 8 * 60),
            TimingPolicy.custom(arrival: nil, focus: 40 * 60, suggestedBreak: 10 * 60),
            TimingPolicy.custom(arrival: nil, focus: 50 * 60, suggestedBreak: 8 * 60),
            TimingPolicy.custom(arrival: nil, focus: 50 * 60, suggestedBreak: 10 * 60),
        ])
        #expect(custom.count == 4)
        #expect(Set(custom) == expectedPairs)

        rhythm.focusPresets = []
        app.setRhythm(rhythm)
        let breakOnly = app.availablePolicies.filter { $0.name.hasPrefix("custom:") }
        let breakOnlyFocus: [TimeInterval?] = breakOnly.map(\.focus)
        let breakOnlyDurations: [TimeInterval] = breakOnly.map(\.suggestedBreak)
        let expectedBreakOnlyFocus: [TimeInterval?] = [
            TimingPolicy.classic.focus, TimingPolicy.classic.focus,
        ]
        let expectedBreakOnlyDurations: [TimeInterval] = [8 * 60, 10 * 60]
        #expect(breakOnlyFocus == expectedBreakOnlyFocus)
        #expect(breakOnlyDurations == expectedBreakOnlyDurations)

        rhythm.focusPresets = [40 * 60, 50 * 60]
        rhythm.breakPresets = []
        app.setRhythm(rhythm)
        let focusOnly = app.availablePolicies.filter { $0.name.hasPrefix("custom:") }
        let focusOnlyDurations: [TimeInterval?] = focusOnly.map(\.focus)
        let focusOnlyBreaks: [TimeInterval] = focusOnly.map(\.suggestedBreak)
        let expectedFocusOnlyDurations: [TimeInterval?] = [40 * 60, 50 * 60]
        let expectedFocusOnlyBreaks: [TimeInterval] = [
            TimingPolicy.classic.suggestedBreak, TimingPolicy.classic.suggestedBreak,
        ]
        #expect(focusOnlyDurations == expectedFocusOnlyDurations)
        #expect(focusOnlyBreaks == expectedFocusOnlyBreaks)
    }

    @Test func testRemovingPresetLeavesStoredSessionReadableAndDerivationUnchanged() throws {
        let store = try LocalStore(inMemory: true)
        let defaults = scratchDefaults()
        let first = AppModel(store: store, clock: { self.t0 }, defaults: defaults)
        var rhythm = first.rhythm
        rhythm.focusPresets = [40 * 60]
        rhythm.breakPresets = [8 * 60]
        first.setRhythm(rhythm)
        first.policy = try #require(first.availablePolicies.first { $0.name.hasPrefix("custom:") })
        try first.begin()

        let storedName = try #require(store.latestSession()?.policyName)
        let storedBytes = Data(storedName.utf8)
        first.setRhythm(.factory)

        let relaunched = AppModel(
            store: store, clock: { self.t0.addingTimeInterval(10 * 60) }, defaults: defaults)
        try relaunched.restore()
        #expect(String(data: storedBytes, encoding: .utf8) == storedName)
        #expect(try store.latestSession()?.policyName == storedName)
        #expect(relaunched.policy.focus == TimeInterval(40 * 60))
        #expect(relaunched.policy.suggestedBreak == 8 * 60)
        #expect(
            relaunched.snapshot(at: self.t0.addingTimeInterval(10 * 60)).remaining
                == TimeInterval(30 * 60))
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
            "masterVolume", "blockStart", "focusTick", "breakTick", "focusEndChime", "breakEndChime",
            "tickLoop", "blockEndEnabled", "breakEndEnabled", "blockEndText", "breakEndText",
            "bringToFront",
        ] {
            #expect(pane.contains(field), "Sound & Notifications pane does not bind \(field)")
        }
    }

    @Test func testSoundPaneExposesFiveExactSampleControls() throws {
        let pane = try source("Surfaces/SoundNotificationsPane.swift")
        for (identifier, label) in [
            ("sound-sample-block-start", "Play Block start sample"),
            ("sound-sample-focus-tick", "Play Focus tick sample"),
            ("sound-sample-break-tick", "Play Break tick sample"),
            ("sound-sample-focus-end", "Play Focus end sample"),
            ("sound-sample-break-end", "Play Break end sample"),
        ] {
            #expect(pane.contains(identifier))
            #expect(pane.contains(label))
        }
        #expect(pane.components(separatedBy: "model.previewSound(").count - 1 == 1)
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

    @Test func testPanesWireAccessibilityEnvironmentsToPaletteTokens() throws {
        for (file, type) in [
            ("Surfaces/RhythmPane.swift", "struct RhythmPane: View"),
            ("Surfaces/SoundNotificationsPane.swift", "struct SoundNotificationsPane: View"),
        ] {
            let code = Self.codeOnly(try source(file))
            let typeBody = try #require(Self.balancedBody(after: type, in: code))
            let body = try #require(Self.balancedBody(after: "var body: some View", in: typeBody))
            let compactType = typeBody.filter { !$0.isWhitespace }
            let compactBody = body.filter { !$0.isWhitespace }
            #expect(compactType.contains("@Environment(\\.colorSchemeContrast)privatevarcontrast"))
            #expect(compactType.contains("@Environment(\\.accessibilityReduceTransparency)privatevarreduceTransparency"))
            #expect(
                compactBody.contains(
                    ".foregroundStyle(SurfacePalette.primaryText(increasedContrast:contrast==.increased))"))
            #expect(
                compactBody.contains(
                    ".background(SurfacePalette.background(reduceTransparency:reduceTransparency))"))
        }
    }

    @Test func testActualSettingsPanesUseIncreaseContrastTokens() throws {
        let app = try model(defaults: scratchDefaults())
        let probe = RenderAccessibilityTests()
        try probe.assertActualSurfaceContrast(
            { RhythmPane(model: app) }, width: 640, height: 560, name: "RhythmPane")
        try probe.assertActualSurfaceContrast(
            { SoundNotificationsPane(model: app) }, width: 640, height: 560,
            name: "SoundNotificationsPane")
    }

    @Test func testActualSettingsPanesHonorReduceTransparency() throws {
        let app = try model(defaults: scratchDefaults())
        let probe = RenderAccessibilityTests()
        try probe.assertActualSurfaceTransparency(
            RhythmPane(model: app), width: 640, height: 560, name: "RhythmPane")
        try probe.assertActualSurfaceTransparency(
            SoundNotificationsPane(model: app), width: 640, height: 560,
            name: "SoundNotificationsPane")
    }
}
