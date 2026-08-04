import Foundation
import PraxmodoroCore
import Testing

@testable import Praxmodoro
import PraxmodoroStore

/// Spec: companion-surfaces "Menu-bar popover operates the loop",
/// "Companion surfaces are never paywalled", and the hard half of
/// "One canonical session state for every surface".
///
/// Two independent validators have now defeated a substring-based guard here.
/// The first aged a captured baseline and formatted it with two
/// `String(format:)` calls; the second used `@State` plus
/// `.task { Task.sleep }` and string interpolation, needing no banned token at
/// all. Both times the whole suite stayed green.
///
/// The lesson taken: a longer blocklist is not the answer. Companion surfaces
/// now receive a `CompanionDisplay` — already-rendered strings, no
/// `TimeInterval` — hold no mutable state, and take no lifecycle or async
/// hook. `testCompanionSurfacesCannotHostASecondClock` checks all three, and
/// says plainly what it does and does not prove.
@MainActor
@Suite struct CompanionSurfaceTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func snapshot(policy: TimingPolicy = .classic, at offset: TimeInterval, hold: Bool = false) throws -> SessionSnapshot {
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.firstAction = "Open the file and read the first heading"
        model.policy = policy
        try model.begin()
        now = t0.addingTimeInterval(offset)
        if hold { try model.toggleHold() }
        return model.snapshot(at: now)
    }

    // A held session offers resume, and says so — the popover reads the phase
    // rather than tracking a toggle of its own.
    @Test func testPopoverShowsHeldStateAndOffersResume() throws {
        let popover = MenuBarPopover(display: try snapshot(at: 5 * 60, hold: true).display, actions: .inert)

        #expect(popover.display.phase == .held)
        #expect(popover.statusText == "Held — your place is kept")
        #expect(popover.primaryControlLabel == "Resume")
        #expect(popover.timeText == "20:00")
        #expect(popover.controls.contains("popover-check-in"))
    }

    // Running sessions offer hold.
    @Test func testPopoverWhileRunningOffersHold() throws {
        let popover = MenuBarPopover(display: try snapshot(at: 8 * 60).display, actions: .inert)

        #expect(popover.primaryControlLabel == "Hold")
        #expect(popover.statusText == "Focusing")
        #expect(popover.timeText == "17:00")
    }

    // With no session there is nothing to count: the popover offers a
    // beginning and renders no clock at all.
    @Test func testPopoverWithoutSessionOffersBeginAndNoTime() throws {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })
        let popover = MenuBarPopover(display: model.snapshot(at: t0).display, actions: .inert)

        #expect(popover.primaryControlLabel == "Begin")
        #expect(popover.timeText == nil)
        #expect(!popover.controls.contains("popover-time"))
    }

    // Spec: "Popover carries no scoring".
    @Test func testPopoverCarriesNoScoringOrUpsell() throws {
        let banned = ["streak", "score", "grade", "percent", "rank", "upgrade", "pro", "unlock", "trial"]
        for phase in [try snapshot(at: 60), try snapshot(at: 60, hold: true)] {
            let popover = MenuBarPopover(display: phase.display, actions: .inert)
            let rendered = (popover.controls + [popover.statusText, popover.primaryControlLabel, popover.accessibilityLabel])
                .joined(separator: " ")
                .lowercased()
            for term in banned {
                #expect(!rendered.contains(term), "menu-bar popover renders “\(term)”")
            }
        }
    }

    // Spec: "Companion surface keys cannot be gated off Lite".
    @Test func testCompanionSurfaceKeysAreNeverPaywalled() {
        let companionKeys: Set<FeatureKey> = [.menuBarSurface, .focusCapsule, .returnOverlay]
        #expect(companionKeys.isSubset(of: CapabilityRegistry.neverPaywalled))

        // A registry that tries to withhold them still resolves them, and
        // startup validation refuses the configuration.
        let withheld = Set(FeatureKey.allCases).subtracting(companionKeys)
        let hostile = CapabilityRegistry(edition: .lite, grants: [.lite: withheld, .pro: withheld, .enterprise: withheld])
        for key in companionKeys {
            #expect(hostile.isAvailable(key), "\(key) must resolve as available even when a configuration withholds it")
        }
        #expect(throws: CapabilityRegistry.ValidationError.self) { try hostile.validate() }
    }

    /// Three independent barriers against a second clock in a companion
    /// surface. Each is checked separately, because the first version of this
    /// guard was a single substring blocklist and an independent validator
    /// defeated it: `@State driftSeconds` aged by
    /// `.task { try? await Task.sleep(…) }`, formatted by string
    /// interpolation, needed none of the banned tokens.
    ///
    /// 1. **No raw interval.** The surface receives a `CompanionDisplay`,
    ///    whose `timeText` is already a string. There is no `TimeInterval` to
    ///    do arithmetic on.
    /// 2. **No mutable state.** No `@State`/`@StateObject`, so there is
    ///    nowhere to keep a drifting value.
    /// 3. **No beat.** No lifecycle or async hook — `.task`, `onAppear`,
    ///    `onReceive`, `Task.sleep`, `asyncAfter`, `RunLoop`, `Timer` — so
    ///    nothing can run on a schedule.
    ///
    /// Honest limit: this is defense in depth, not a proof. An author who
    /// parsed `timeText` back into numbers and found some other beat could
    /// still misbehave. What these barriers remove is the demonstrated
    /// failure mode, not every conceivable one.
    @Test func testCompanionSurfacesCannotHostASecondClock() throws {
        let surfaces = ["MenuBarPopover.swift", "FocusCapsule.swift", "ReturnOverlay.swift"]
        let surfacesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent("Surfaces")

        // Barrier 3: every way found so far to make code run over time.
        let beats = [
            "Task.sleep", "asyncAfter", "RunLoop", "CFAbsoluteTime", "DispatchTime", "DispatchSourceTimer",
            "Timer", "TimelineView", ".task {", "onAppear", "onReceive", "AsyncStream", "Task.detached",
            "Task {", "ContinuousClock", "SuspendingClock",
        ]
        // Reading the wall clock or the model at all.
        let clockAccess = ["Date(", ".now", "timeIntervalSince", "AppModel"]
        // Barrier 2: nowhere to keep a drifting value.
        let mutableState = ["@State", "@StateObject", "@ObservedObject", "var body: some View {\n        var "]

        for name in surfaces {
            let url = surfacesDir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)

            // Barrier 1: the input carries no interval to age.
            #expect(source.contains("CompanionDisplay"),
                    "\(name) must take a CompanionDisplay, whose time is already a string")
            #expect(!source.contains("SessionSnapshot"),
                    "\(name) takes a SessionSnapshot, which exposes a raw TimeInterval it could age")
            #expect(!source.contains("String(format:"),
                    "\(name) formats a number into time; CompanionDisplay hands it a finished string")

            for token in beats + clockAccess + mutableState {
                #expect(!source.contains(token),
                        "\(name) can host a second clock via “\(token)”")
            }
        }
    }

    // A correct colour recipe that nothing calls is not an accessibility
    // alternate. Every companion surface must actually read the system
    // settings and draw from SurfacePalette (spec: companion-surfaces
    // "Accessibility alternates on every companion surface").
    @Test func testCompanionSurfacesReadTheAccessibilityEnvironment() throws {
        let surfaces = ["MenuBarPopover.swift", "FocusCapsule.swift", "ReturnOverlay.swift"]
        let surfacesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent("Surfaces")

        for name in surfaces {
            // Surfaces land across atoms g4-g6; each is held to the rule as
            // soon as it exists. `CompanionAccessibilityTests` (atom g7) pins
            // that all three are present once the set is complete.
            let url = surfacesDir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            #expect(source.contains("accessibilityReduceTransparency"),
                    "\(name) never reads Reduce Transparency, so its opaque alternate can never engage")
            #expect(source.contains("accessibilityReduceMotion"),
                    "\(name) never reads Reduce Motion, so the physics standdown can never engage")
            #expect(source.contains("SurfacePalette.background(reduceTransparency:"),
                    "\(name) does not draw its background from the verified palette")
        }
    }

    // Exactly one place may read the wall clock for rendering, and only to ask
    // the model for a fresh snapshot at that instant.
    @Test func testClockReadsOnlyFeedSnapshotCalls() throws {
        let surfacesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent("Surfaces")
        let enumerator = try #require(FileManager.default.enumerator(at: surfacesDir, includingPropertiesForKeys: nil))

        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
                let code = line.contains("//") ? String(line[..<(line.range(of: "//")?.lowerBound ?? line.endIndex)]) : String(line)
                guard code.contains("Date()") || code.contains("context.date") else { continue }
                #expect(code.contains("snapshot(at:"),
                        "\(file.lastPathComponent) reads the clock for something other than a snapshot: \(code.trimmingCharacters(in: .whitespaces))")
            }
        }
    }
}
