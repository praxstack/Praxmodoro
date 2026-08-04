import Foundation
import PraxmodoroCore
import Testing

@testable import Praxmodoro
import PraxmodoroStore

/// Spec: companion-surfaces "One canonical session state for every surface".
/// The snapshot is the only thing a surface may render; these tests pin that
/// it derives from the engine and that no surface grows a second clock.
@MainActor
@Suite struct SnapshotTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func startedModel(policy: TimingPolicy = .classic, at now: Date) throws -> AppModel {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.firstAction = "Open the file and read the first heading"
        model.policy = policy
        try model.begin()
        return model
    }

    // Remaining time is f(transitions, now) — the snapshot recomputes it from
    // the engine at the instant asked for, never from an accumulated count.
    @Test func testSnapshotDerivesRemainingFromTransitions() throws {
        let model = try startedModel(at: t0)
        let eightMinutesIn = t0.addingTimeInterval(8 * 60)

        let snapshot = model.snapshot(at: eightMinutesIn)

        #expect(snapshot.phase == .running)
        #expect(snapshot.taskLine == "Edit the outline")
        #expect(snapshot.nextAction == "Open the file and read the first heading")
        #expect(snapshot.remaining == TimeInterval(17 * 60))
        #expect(snapshot.remainingText == "17:00")
        // Asking twice at the same instant is the same answer; asking later is
        // a smaller one. Nothing is stored between the two calls.
        #expect(model.snapshot(at: eightMinutesIn) == snapshot)
        #expect(model.snapshot(at: t0.addingTimeInterval(9 * 60)).remaining == TimeInterval(16 * 60))
    }

    // An open-ended policy has no remaining interval, and the text says so
    // rather than showing a zero or a placeholder count.
    @Test func testSnapshotOpenEndedBlockHasNoRemaining() throws {
        let model = try startedModel(policy: .flow, at: t0)

        let snapshot = model.snapshot(at: t0.addingTimeInterval(45 * 60))

        #expect(snapshot.remaining == nil)
        #expect(snapshot.remainingText == "open")
        #expect(snapshot.accessibilitySummary == "Companion: breathing, open-ended block")
    }

    // With no session there is nothing to count down: the snapshot reports no
    // remaining text at all, so a surface cannot render a stale or zero clock.
    @Test func testSnapshotWithoutSessionHasNoRemainingText() throws {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { self.t0 })

        let snapshot = model.snapshot(at: t0)

        #expect(snapshot.phase == .idle)
        #expect(snapshot.remaining == nil)
        #expect(snapshot.remainingText == nil)
        #expect(!snapshot.hasSession)
    }

    // Held sessions keep their place: the remaining value stops moving while
    // held, which is the engine's behavior surfaced verbatim.
    @Test func testSnapshotHoldFreezesRemaining() throws {
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.policy = .classic
        try model.begin()
        now = t0.addingTimeInterval(5 * 60)
        try model.toggleHold()

        let atHold = model.snapshot(at: now)
        let tenMinutesLater = model.snapshot(at: now.addingTimeInterval(10 * 60))

        #expect(atHold.phase == .held)
        #expect(atHold.remaining == TimeInterval(20 * 60))
        #expect(tenMinutesLater.remaining == TimeInterval(20 * 60))
        #expect(tenMinutesLater.accessibilitySummary == "Companion: holding your place")
    }

    // Sleep, wake, relaunch: the snapshot taken after a gap during which the
    // app was not running reports the canonical value, with no tick drift.
    @Test func testSnapshotAfterSleepHasNoDrift() throws {
        let model = try startedModel(at: t0)
        let afterFourHours = t0.addingTimeInterval(4 * 60 * 60)

        let snapshot = model.snapshot(at: afterFourHours)

        // 25 minutes of focus were long since spent; the clamp holds at zero
        // instead of running negative or inflating.
        #expect(snapshot.remaining == TimeInterval(0))
        #expect(snapshot.remainingText == "00:00")
        #expect(snapshot.remaining == model.remaining(at: afterFourHours))
    }

    /// Module-wide: nothing in the app sources may run code on a schedule.
    ///
    /// A validator defeated the surface-scoped guard by parking the beat in a
    /// *different* file (`SurfacePalette.swift`) and consuming it from the
    /// popover through statics. A per-file scan of three filenames cannot see
    /// that, so this scan covers every source file in the target. The app has
    /// no legitimate use for a scheduled beat: the only periodic rendering is
    /// `TimelineView`, which re-derives from the engine instead of counting.
    ///
    /// Comments are stripped first — this file's own documentation names the
    /// constructs it bans.
    @Test func testNothingInTheAppRunsOnASchedule() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil))

        let beats = [
            "Timer(", "Timer.publish", "scheduledTimer", "DispatchSourceTimer",
            "Task.sleep", "asyncAfter", "Task.detached", "RunLoop.", "CFAbsoluteTime",
            "ContinuousClock", "SuspendingClock", "AsyncTimerSequence",
            // A validator's fourth defeat used ProcessInfo.systemUptime, which
            // is a clock even though it never says "Date" or "Timer".
            "ProcessInfo", "systemUptime", "mach_absolute_time", "clock_gettime",
            "DispatchWallTime", "uptimeNanoseconds", "monotonic",
        ]
        var sawSnapshotUse = false
        var scanned = 0

        for case let file as URL in enumerator where file.pathExtension == "swift" {
            scanned += 1
            let raw = try String(contentsOf: file, encoding: .utf8)
            let code = raw.split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> String in
                    guard let comment = line.range(of: "//") else { return String(line) }
                    return String(line[..<comment.lowerBound])
                }
                .joined(separator: "\n")

            for beat in beats {
                #expect(!code.contains(beat),
                        "\(file.lastPathComponent) can run code on a schedule via “\(beat)”; the engine is the only clock")
            }
            // Only the snapshot may turn an interval into a clock face.
            if file.lastPathComponent != "SessionSnapshot.swift" {
                #expect(!code.contains("%02d:%02d"),
                        "\(file.lastPathComponent) formats remaining time locally; SessionSnapshot owns that")
            }
            if code.contains("snapshot(at:") { sawSnapshotUse = true }
        }

        #expect(scanned > 10, "the scan must actually cover the app sources; only \(scanned) files seen")
        #expect(sawSnapshotUse, "nothing reads snapshot(at:); the canonical projection is unused")
    }
}
