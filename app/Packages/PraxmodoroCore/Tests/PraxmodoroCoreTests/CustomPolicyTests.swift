import Foundation
import Testing
@testable import PraxmodoroCore

/// Spec: add-session-settings — "Custom rhythm durations" (tasks 1.1–1.3).
@Suite struct CustomPolicyTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func testCustomPolicyDrivesDerivation() throws {
        let policy = TimingPolicy.custom(arrival: nil, focus: 40 * 60, suggestedBreak: 8 * 60)
        var session = Session(policy: policy, startedAt: nil)
        try session.apply(.begin, at: t0)
        let remaining = try #require(session.remaining(at: t0.addingTimeInterval(10 * 60)))
        #expect(remaining == TimeInterval(30 * 60))
    }

    @Test func testCustomPolicyNameRoundTrips() throws {
        let policy = TimingPolicy.custom(arrival: 5 * 60, focus: 40 * 60, suggestedBreak: 8 * 60)
        let resolved = TimingPolicy.named(policy.name)
        #expect(resolved == policy)
    }

    @Test func testCustomPolicySurvivesRelaunch() throws {
        // The store persists only the policy name and transitions; a custom
        // policy must reconstruct exactly from those two, like presets do.
        let policy = TimingPolicy.custom(arrival: nil, focus: 40 * 60, suggestedBreak: 8 * 60)
        var original = Session(policy: policy, startedAt: nil)
        try original.apply(.begin, at: t0)

        let restored = Session(policy: TimingPolicy.named(policy.name), transitions: original.transitions)
        let later = t0.addingTimeInterval(12 * 60)
        #expect(restored.remaining(at: later) == original.remaining(at: later))
        #expect(restored.remaining(at: later) == TimeInterval(28 * 60))
    }

    @Test func testUnparseableCustomNameFallsBackToClassic() {
        #expect(TimingPolicy.named("custom:garbage") == .classic)
        #expect(TimingPolicy.named("nonsense") == .classic)
    }

    @Test func testBuiltInNamesStillResolve() {
        #expect(TimingPolicy.named("gentle-start") == .gentleStart)
        #expect(TimingPolicy.named("flow") == .flow)
    }
}

/// Spec: add-session-settings — "Long-break cadence suggests, never scores"
/// (task 1.2). The cadence is derived from transition history alone; nothing
/// counts blocks anywhere else.
@Suite struct LongBreakCadenceTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Run `blocks` full focus→break cycles, then ask what the break after
    /// the final block-end should suggest.
    private func session(afterBlocks blocks: Int) throws -> Session {
        var session = Session(policy: .classic, startedAt: nil)
        var t = t0
        try session.apply(.begin, at: t)
        for index in 0..<blocks {
            t = t.addingTimeInterval(25 * 60)
            try session.apply(.startBreak, at: t)
            if index < blocks - 1 {
                t = t.addingTimeInterval(5 * 60)
                try session.apply(.endBreak, at: t)
            }
        }
        return session
    }

    @Test func testNthBlockEndSuggestsLongBreak() throws {
        let cadence = LongBreakCadence(everyBlocks: 4, length: 15 * 60)
        let session = try session(afterBlocks: 4)
        #expect(session.suggestedBreakLength(cadence: cadence) == TimeInterval(15 * 60))
    }

    @Test func testOtherBlockEndsSuggestOrdinaryBreak() throws {
        let cadence = LongBreakCadence(everyBlocks: 4, length: 15 * 60)
        for blocks in [1, 2, 3, 5] {
            let session = try session(afterBlocks: blocks)
            #expect(session.suggestedBreakLength(cadence: cadence) == TimeInterval(5 * 60))
        }
    }

    @Test func testNoCadenceMeansPolicyBreak() throws {
        let session = try session(afterBlocks: 4)
        #expect(session.suggestedBreakLength(cadence: nil) == TimeInterval(5 * 60))
    }
}
