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

    /// Module-wide: nothing in the app sources may run code on a schedule,
    /// and nothing may read the wall clock except to feed `snapshot(at:)` or
    /// through one of three named, audited seams.
    ///
    /// History, because the shape of this test is the residue of six defeats:
    /// a validator parked a beat in a *different* file and read it through
    /// statics (third defeat), so this scan went module-wide; another used
    /// `ProcessInfo.systemUptime` (fourth), so the beat list grew clock
    /// sources; the sixth parked a bare `Date()` **diff** — no scheduling
    /// primitive at all — in `SurfacePalette.swift` with a one-hour period,
    /// which evaded every surface-scoped scan and outlasted the drift test's
    /// finite window. So raw clock reads are now banned module-wide at line
    /// level, with an explicit allowlist of the three legitimate reads.
    ///
    /// Honest limits, stated plainly: this is a lint over text, and the drift
    /// test's window is finite — **no finite-window behavioural test can
    /// prove the absence of an arbitrarily slow clock.** The durable close is
    /// a compiler-enforced module boundary for the pure surfaces, recorded as
    /// deferred in the change's design.md. Until then this allowlist is the
    /// narrowest gate we can hold.
    @Test func testNothingInTheAppRunsOnASchedule() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil))

        let beats = [
            "Timer(", "Timer.publish", "scheduledTimer", "DispatchSourceTimer",
            "Task.sleep", "asyncAfter", "Task.detached", "RunLoop.", "CFAbsoluteTime",
            "ContinuousClock", "SuspendingClock", "AsyncTimerSequence",
            "ProcessInfo", "systemUptime", "mach_absolute_time", "clock_gettime",
            "DispatchWallTime", "uptimeNanoseconds", "monotonic",
        ]
        // Reading the wall clock at all. `Date.init` catches the spelling that
        // dodges the literal `Date(`.
        let clockReads = ["Date(", "Date.init", ".timeIntervalSince"]
        // Every legitimate raw read, one by one. Adding a line here is a
        // reviewable act, which is the point.
        let allowedReads: [(file: String, line: String)] = [
            // The injected-clock seam's default. Tests replace it; production
            // time enters the app here and nowhere else.
            ("AppModel.swift", "clock: @escaping () -> Date = { Date() }"),
            // Startup timestamp for naming a corrupt-store recovery file.
            ("PraxmodoroApp.swift", "LocalStore.open("),
            // Frame delta between TimelineView ticks — presentation dt for the
            // physics integrator, never session time.
            ("CompanionFieldView.swift", "lastTick.map { now.timeIntervalSince($0) }"),
            // The audio scheduler's own clock seam, mirroring AppModel's.
            ("SoundDirector.swift", "private let clock: () -> Date = { Date() }"),
            // Converting a canonical engine instant into the audio device's
            // timebase — presentation lead time, never session arithmetic.
            ("SoundDirector.swift", "instant.timeIntervalSince(clock())"),
        ]

        var sawSnapshotUse = false
        var scanned = 0

        for case let file as URL in enumerator where file.pathExtension == "swift" {
            scanned += 1
            let raw = try String(contentsOf: file, encoding: .utf8)
            let codeLines = raw.split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> String in
                    guard let comment = line.range(of: "//") else { return String(line) }
                    return String(line[..<comment.lowerBound])
                }
            let code = codeLines.joined(separator: "\n")

            for beat in beats {
                #expect(!code.contains(beat),
                        "\(file.lastPathComponent) can run code on a schedule via “\(beat)”; the engine is the only clock")
            }

            for line in codeLines where clockReads.contains(where: line.contains) {
                // A read that exists only to ask the model for a fresh
                // snapshot at that instant is the sanctioned pattern.
                if line.contains("snapshot(at:") { continue }
                let allowed = allowedReads.contains {
                    $0.file == file.lastPathComponent && line.contains($0.line)
                }
                #expect(allowed,
                        "\(file.lastPathComponent) reads the wall clock outside the allowlist: \(line.trimmingCharacters(in: .whitespaces))")
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
