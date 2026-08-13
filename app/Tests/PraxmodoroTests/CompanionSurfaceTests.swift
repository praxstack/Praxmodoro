import Foundation
import CoreGraphics
import PraxmodoroCore
import SwiftUI
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

    // Spec: "Lite grants every companion surface" — "no surface SHALL render
    // an upsell". The popover has its own test above; the capsule and the
    // overlay were previously covered only by inspection.
    @Test func testNoCompanionSurfaceRendersScoringOrUpsell() throws {
        let banned = ["streak", "score", "grade", "percent", "rank", "upgrade", "unlock", "trial", "premium", "subscribe"]
        for frozen in [try snapshot(at: 60).display, try snapshot(at: 60, hold: true).display] {
            let rendered = (Array(PureSurfaces(frozen).strings.values)
                + MenuBarPopover(display: frozen, actions: .inert).controls
                + FocusCapsule(display: frozen, actions: .inert).controls
                + ReturnOverlay.controls)
                .joined(separator: " ")
                .lowercased()
            for term in banned {
                #expect(!rendered.contains(term), "a companion surface renders “\(term)”")
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

    /// The four pure surfaces, built once and held.
    ///
    /// Holding the instances matters: a clock captured at construction (the
    /// fourth defeat used `ProcessInfo.systemUptime` in a `private let`) is
    /// invisible if the surfaces are rebuilt after the wait, because
    /// construction resets it. The surfaces must be the same objects before
    /// and after.
    @MainActor
    private struct PureSurfaces {
        let popover: MenuBarPopover
        let capsule: FocusCapsule
        let overlay: ReturnOverlay
        let readout: RemainingReadout

        init(_ frozen: CompanionDisplay) {
            popover = MenuBarPopover(display: frozen, actions: .inert, motionStilledOverride: true)
            capsule = FocusCapsule(display: frozen, actions: .inert, motionStilledOverride: true)
            overlay = ReturnOverlay(display: frozen, onAcknowledge: {}, motionStilledOverride: true)
            readout = RemainingReadout(display: frozen)
        }

        /// What each surface actually *renders*, rasterized from the held
        /// instances.
        ///
        /// Reading named properties is not enough: the fifth defeat put the
        /// clock read inside `body`, where no property-reading test could see
        /// it. Rasterizing covers everything the user can see. Reduce Motion is
        /// forced on so the companion field's legitimate animation cannot make
        /// the comparison flap — with the physics stood down, any pixel change
        /// is drift.
        func bitmaps() throws -> [String: Data] {
            [
                "popover": try Self.rasterize(popover),
                "capsule": try Self.rasterize(capsule),
                "overlay": try Self.rasterize(overlay),
                "readout": try Self.rasterize(readout),
            ]
        }

        private static func rasterize(_ view: some View, width: CGFloat = 300, height: CGFloat = 200) throws -> Data {
            let renderer = ImageRenderer(
                // Composited over an opaque backdrop: on a transparent one
                // the premultiplied text pixels are too faint for a
                // per-pixel threshold to see.
                content: ZStack {
                    Color.white
                    view
                }
                .frame(width: width, height: height))
            renderer.scale = 1
            let image = try #require(renderer.cgImage, "ImageRenderer produced no bitmap")

            let pixelWidth = Int(width)
            let pixelHeight = Int(height)
            var buffer = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
            let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let context = try #require(
                CGContext(
                    data: &buffer, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
                    bytesPerRow: pixelWidth * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return Data(buffer)
        }

        /// Every user-visible string, read fresh from the held instances.
        var strings: [String: String] {
            [
                "popover.timeText": popover.timeText ?? "nil",
                "popover.statusText": popover.statusText,
                "popover.primaryControlLabel": popover.primaryControlLabel,
                "popover.accessibilityLabel": popover.accessibilityLabel,
                "capsule.timeText": capsule.timeText ?? "nil",
                "capsule.taskText": capsule.taskText,
                "capsule.accessibilityLabel": capsule.accessibilityLabel,
                "overlay.wayBack": overlay.wayBack,
                "overlay.accessibilityLabel": overlay.accessibilityLabel,
                "readout.text": readout.text,
            ]
        }
    }

    /// **The behavioral net.** Four static guards have now been defeated —
    /// a baseline aged with `timeIntervalSince`; `@State` aged by
    /// `.task { Task.sleep }`; a beat parked in a *different file* and read
    /// through statics; and `ProcessInfo.systemUptime`, which is a clock that
    /// never says "Date" or "Timer". Each defeat came from a real, compiling,
    /// genuinely drifting counterexample.
    ///
    /// Static checks cannot settle this. Behavior can: freeze the input, let
    /// real wall-clock time pass, and read every rendered string again. A pure
    /// function of a frozen input cannot change, so a second clock fails this
    /// wherever its beat lives and whatever it is spelled.
    ///
    /// The fourth defeat exploited *coverage*, not the method — the previous
    /// version instantiated only two of the four pure surfaces.
    /// `testDriftCoverageIncludesEveryPureSurface` closes that class.
    @Test func testPureSurfacesDoNotDriftFromTheirInput() async throws {
        let frozen = try snapshot(at: 8 * 60).display
        let surfaces = PureSurfaces(frozen)
        let beforeStrings = surfaces.strings
        let beforePixels = try surfaces.bitmaps()
        #expect(beforeStrings["popover.timeText"] == "17:00")
        #expect(beforeStrings["capsule.timeText"] == "17:00")

        // Long enough to catch a per-second beat with margin. A beat slower
        // than this window would evade it; no finite wait can rule that out,
        // and pretending otherwise is how the previous four claims went wrong.
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Same instances, read again. Nothing about the input changed.
        let afterStrings = surfaces.strings
        for (name, value) in beforeStrings {
            #expect(afterStrings[name] == value,
                    "\(name) drifted from a frozen input: “\(value)” became “\(afterStrings[name] ?? "nil")”")
        }

        // And what actually renders — `body` included — must not change.
        //
        // Compared by mean absolute pixel difference rather than byte
        // equality: rasterizing blurred gradients is not bit-reproducible, so
        // an exact match would flap. A clock read inside `body` changes glyphs,
        // which moves this by orders of magnitude more than renderer noise.
        // `testDriftPixelComparisonCanFail` pins the threshold's sensitivity.
        let afterPixels = try surfaces.bitmaps()
        for (name, pixels) in beforePixels {
            let difference = Self.changedPixelFraction(pixels, try #require(afterPixels[name]))
            #expect(difference <= Self.renderNoiseTolerance,
                    "\(name) rendered differently from a frozen input (\(difference) of pixels changed); something inside its body reads a clock")
        }
    }

    /// Fraction of pixels allowed to change materially between two renders of
    /// identical content.
    ///
    /// A mean-difference metric put one changed glyph at 0.056 against a 0.05
    /// budget — far too thin to trust. Counting materially-changed pixels
    /// separates them properly: measured noise is exactly zero on all four
    /// surfaces, one changed digit moves 0.0075, and the smallest real exploit
    /// seen (a two-character beat in the capsule) moves 0.00085 — well clear of
    /// this threshold. `testDriftPixelComparisonCanFail` re-measures the noise
    /// floor on every run, so if rasterization ever stops being deterministic
    /// it fails with that reason instead of flaking.
    static let renderNoiseTolerance = 0.0001

    /// Fraction of pixels whose colour moved by more than a just-noticeable
    /// amount in any channel.
    static func changedPixelFraction(_ lhs: Data, _ rhs: Data) -> Double {
        guard lhs.count == rhs.count, lhs.count >= 4 else { return .infinity }
        let threshold = 8
        var changed = 0
        var index = 0
        while index + 3 < lhs.count {
            if abs(Int(lhs[index]) - Int(rhs[index])) > threshold
                || abs(Int(lhs[index + 1]) - Int(rhs[index + 1])) > threshold
                || abs(Int(lhs[index + 2]) - Int(rhs[index + 2])) > threshold
            {
                changed += 1
            }
            index += 4
        }
        return Double(changed) / Double(lhs.count / 4)
    }

    /// The pixel comparison must be able to fail, and must be far more
    /// sensitive than the noise it tolerates.
    @Test func testDriftPixelComparisonCanFail() throws {
        let frozen = try snapshot(at: 8 * 60).display
        let seventeen = PureSurfaces(frozen)
        let sixteen = PureSurfaces(
            CompanionDisplay(
                phase: frozen.phase, taskLine: frozen.taskLine, nextAction: frozen.nextAction,
                timeText: "16:00", statusLine: frozen.statusLine, fieldSummary: frozen.fieldSummary,
                offersAdjustment: frozen.offersAdjustment))

        // Measure the noise floor for every surface, so nondeterministic
        // rasterization shows up as a clear failure rather than a flake.
        let first = try seventeen.bitmaps()
        let second = try seventeen.bitmaps()
        var noise = 0.0
        for (name, pixels) in first {
            let delta = Self.changedPixelFraction(pixels, try #require(second[name]))
            #expect(delta <= Self.renderNoiseTolerance,
                    "\(name) does not rasterize deterministically (noise \(delta)); the drift threshold cannot be trusted")
            noise = max(noise, delta)
        }
        let oneGlyph = Self.changedPixelFraction(try #require(first["readout"]), try #require(sixteen.bitmaps()["readout"]))

        #expect(oneGlyph > Self.renderNoiseTolerance,
                "a single changed digit (17:00 -> 16:00) moved only \(oneGlyph) of pixels, inside the tolerance; the probe is blind")
        #expect(oneGlyph > Self.renderNoiseTolerance * 10,
                "one changed digit must dwarf the tolerance, not skim it: \(oneGlyph) vs \(Self.renderNoiseTolerance)")
        #expect(noise == 0 || oneGlyph > noise * 10, "one changed digit must dwarf renderer noise: \(oneGlyph) vs \(noise)")
    }

    /// A drift test that misses a surface is how the fourth defeat happened:
    /// the previous version instantiated only the popover and the readout, so
    /// a clock added to `FocusCapsule` sailed through. Adding a pure surface
    /// without adding it to `renderedStrings` now fails here.
    @Test func testDriftCoverageIncludesEveryPureSurface() throws {
        let surfacesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent("Surfaces")
        let enumerator = try #require(FileManager.default.enumerator(at: surfacesDir, includingPropertiesForKeys: nil))

        var pureSurfaces: Set<String> = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            if source.contains("let display: CompanionDisplay") {
                pureSurfaces.insert(file.deletingPathExtension().lastPathComponent)
            }
        }

        let probe = CompanionDisplay(
            phase: .running, taskLine: "t", nextAction: "n", timeText: "01:00", statusLine: "s", fieldSummary: "f",
            offersAdjustment: true)
        let covered = Set(PureSurfaces(probe).strings.keys.map { String($0.split(separator: ".")[0]) })

        #expect(covered == ["popover", "capsule", "overlay", "readout"],
                "drift coverage changed unexpectedly: \(covered.sorted())")
        #expect(pureSurfaces == ["MenuBarPopover", "FocusCapsule", "ReturnOverlay", "RemainingReadout"],
                "a pure surface exists that the drift test does not exercise: \(pureSurfaces.sorted())")
    }

    /// Static barriers, kept as defense in depth behind the drift test above.
    /// They catch the in-file spellings cheaply; they are lints, not proof,
    /// and the third defeat proved exactly that.
    ///
    /// 1. **No raw interval** — the surface receives a `CompanionDisplay`,
    ///    whose `timeText` is already a string, so there is no `TimeInterval`
    ///    to do arithmetic on. (Enforced textually here; making it
    ///    compiler-enforced needs a separate module, deferred with reasons in
    ///    the change's design.md.)
    /// 2. **No mutable state** — no `@State`/`@StateObject`.
    /// 3. **No in-file beat** — no `.task`, `onAppear`, `onReceive`,
    ///    `Task.sleep`, `asyncAfter`, `RunLoop`, `Timer`, clock types.
    @Test func testCompanionSurfacesCannotHostASecondClock() throws {
        let surfaces = ["MenuBarPopover.swift", "FocusCapsule.swift", "ReturnOverlay.swift", "RemainingReadout.swift"]
        let surfacesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent("Surfaces")

        // Barrier 3: every way found so far to make code run over time.
        let beats = [
            "Task.sleep", "asyncAfter", "RunLoop", "CFAbsoluteTime", "DispatchTime", "DispatchSourceTimer",
            "Timer", "TimelineView", ".task {", "onAppear", "onReceive", "AsyncStream", "Task.detached",
            "Task {", "ContinuousClock", "SuspendingClock",
            "ProcessInfo", "systemUptime", "mach_absolute_time", "clock_gettime",
            "DispatchWallTime", "uptimeNanoseconds", "monotonic",
        ]
        // Reading the wall clock or the model at all.
        let clockAccess = ["Date(", ".now", "timeIntervalSince", "AppModel"]
        // Barrier 2: nowhere to keep a drifting value.
        let mutableState = ["@State", "@StateObject", "@ObservedObject", "var body: some View {\n        var "]

        for name in surfaces {
            let url = surfacesDir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            // Comments are stripped, as the module-wide scan already does: a
            // doc comment naming AppModel cannot host a clock, and a guard
            // that fails on its own documentation trains people to weaken it.
            let source = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> String in
                    guard let comment = line.range(of: "//") else { return String(line) }
                    return String(line[..<comment.lowerBound])
                }
                .joined(separator: "\n")

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
