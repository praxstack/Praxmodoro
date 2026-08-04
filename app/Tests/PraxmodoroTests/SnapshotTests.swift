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

    // Structural: no surface may construct a timer, schedule a decrement, or
    // keep an elapsed counter, and no surface may format remaining time
    // itself — `snapshot(at:)` is the only source of the rendered value.
    @Test func testNoSurfaceCountsTime() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil))

        let bannedClockConstructions = ["Timer(", "Timer.publish", "scheduledTimer", "DispatchSourceTimer"]
        var sawSnapshotUse = false

        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for construction in bannedClockConstructions {
                #expect(!source.contains(construction),
                        "\(file.lastPathComponent) constructs its own clock (\(construction)); render snapshot(at:) instead")
            }
            // Only the snapshot may turn an interval into a clock face.
            if file.lastPathComponent != "SessionSnapshot.swift" {
                #expect(!source.contains("%02d:%02d"),
                        "\(file.lastPathComponent) formats remaining time locally; SessionSnapshot owns that")
            }
            if source.contains("snapshot(at:") || source.contains("snapshot(at: ") {
                sawSnapshotUse = true
            }
        }

        #expect(sawSnapshotUse, "no surface reads snapshot(at:); the canonical projection is unused")
    }
}
