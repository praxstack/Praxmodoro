import Foundation
import PraxmodoroCore
import Testing

@testable import Praxmodoro
import PraxmodoroStore

/// Spec: companion-surfaces "Menu-bar popover operates the loop",
/// "Companion surfaces are never paywalled", and the hard half of
/// "One canonical session state for every surface".
///
/// The M1-era structural scan was defeated by an independent validator, which
/// added a real second clock to a surface (baseline captured once, aged
/// locally, formatted with two `String(format:)` calls) and watched the whole
/// suite stay green. The answer is not a longer banned-substring list: it is
/// that a companion surface must be a pure function of a snapshot with no
/// clock and no model to reach for. That is what `testCompanionSurfacesAreClockless`
/// pins, and it is why these views take a `SessionSnapshot` value.
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
        let popover = MenuBarPopover(snapshot: try snapshot(at: 5 * 60, hold: true), actions: .inert)

        #expect(popover.snapshot.phase == .held)
        #expect(popover.statusText == "Held — your place is kept")
        #expect(popover.primaryControlLabel == "Resume")
        #expect(popover.timeText == "20:00")
        #expect(popover.controls.contains("popover-check-in"))
    }

    // Running sessions offer hold.
    @Test func testPopoverWhileRunningOffersHold() throws {
        let popover = MenuBarPopover(snapshot: try snapshot(at: 8 * 60), actions: .inert)

        #expect(popover.primaryControlLabel == "Hold")
        #expect(popover.statusText == "Focusing")
        #expect(popover.timeText == "17:00")
    }

    // With no session there is nothing to count: the popover offers a
    // beginning and renders no clock at all.
    @Test func testPopoverWithoutSessionOffersBeginAndNoTime() throws {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })
        let popover = MenuBarPopover(snapshot: model.snapshot(at: t0), actions: .inert)

        #expect(popover.primaryControlLabel == "Begin")
        #expect(popover.timeText == nil)
        #expect(!popover.controls.contains("popover-time"))
    }

    // Spec: "Popover carries no scoring".
    @Test func testPopoverCarriesNoScoringOrUpsell() throws {
        let banned = ["streak", "score", "grade", "percent", "rank", "upgrade", "pro", "unlock", "trial"]
        for phase in [try snapshot(at: 60), try snapshot(at: 60, hold: true)] {
            let popover = MenuBarPopover(snapshot: phase, actions: .inert)
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

    // The structural guard that replaces the one an independent validator
    // defeated. A companion surface has no clock and no model to reach for,
    // so it cannot age a value locally — the exploit is impossible, not merely
    // undetected. (Spec: companion-surfaces "No surface counts time".)
    @Test func testCompanionSurfacesAreClockless() throws {
        let surfaces = ["MenuBarPopover.swift", "FocusCapsule.swift", "ReturnOverlay.swift"]
        let surfacesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources").appendingPathComponent("Surfaces")

        // Anything that could produce or advance a time value.
        let forbidden = ["Date(", ".now", "timeIntervalSince", "TimelineView", "AppModel", "String(format:", "Timer"]

        for name in surfaces {
            let url = surfacesDir.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            for token in forbidden {
                #expect(!source.contains(token),
                        "\(name) can reach a clock via “\(token)”; companion surfaces must be pure functions of a snapshot")
            }
            #expect(source.contains("SessionSnapshot") || source.contains("snapshot:"),
                    "\(name) does not take a snapshot; it cannot be rendering canonical state")
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
