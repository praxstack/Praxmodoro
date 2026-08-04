import Foundation
import PraxmodoroCore
import SwiftData
import Testing

@testable import Praxmodoro
import PraxmodoroStore

/// The M1 closeout recorded four follow-ups that were deferred into M2 rather
/// than waived. Two of them are unit-level and live here; the other two are
/// interface-level and live in `KeyboardLoopUITests`.
@MainActor
@Suite struct HardeningTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // Follow-up: the loop could only reach the check-in surface when one
    // became due, so the keyboard scenario had no way to drive answers 1-4.
    // A user-initiated check-in is the affordance a user would want anyway.
    @Test func testCheckinHasItsOwnKeyboardPath() throws {
        #expect(KeyboardMap.all["checkin-now"] == "⌘K")

        // And it routes through the same entry point, so the timer-held
        // invariant is unchanged.
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        model.policy = .classic
        try model.begin()
        now = t0.addingTimeInterval(4 * 60)

        try model.openCheckin()

        #expect(model.surface == .checkin)
        #expect(model.isHeld, "opening a check-in must hold the timer")
        #expect(model.snapshot(at: now).remaining == TimeInterval(21 * 60))
        #expect(model.snapshot(at: now.addingTimeInterval(5 * 60)).remaining == TimeInterval(21 * 60),
                "the held place must not move while the question is open")
    }

    // Follow-up: the M1 parity test compared the static schema declaration to
    // itself and could not fail. This compares two live containers built from
    // two different configurations (spec: session-persistence
    // "Two-configuration parity against live containers").
    @Test func testSchemaParityAcrossStoreConfigurations() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("praxmodoro-parity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let inMemory = try LocalStore(inMemory: true)
        let onDisk = try LocalStore(url: directory.appendingPathComponent("parity.store"))

        let memoryShape = Self.shape(of: inMemory.containerSchema)
        let diskShape = Self.shape(of: onDisk.containerSchema)

        #expect(!memoryShape.isEmpty, "the live container schema is empty; the comparison would be vacuous")
        #expect(memoryShape == diskShape,
                "store configurations disagree on shape:\nin-memory: \(memoryShape)\non-disk:  \(diskShape)")

        // And no attribute exists to enforce or upsell an edition.
        for attribute in memoryShape {
            let lowered = attribute.lowercased()
            for term in ["edition", "paywall", "upsell", "tier", "license"] {
                #expect(!lowered.contains(term), "edition-shaped schema field: \(attribute)")
            }
        }
    }

    // The parity comparison must be able to fail. A comparison that returns
    // equal for genuinely different shapes proves nothing about the test
    // above, and the M1 version failed exactly that way.
    @Test func testSchemaParityComparisonCanFail() throws {
        let shape = Self.shape(of: try LocalStore(inMemory: true).containerSchema)

        #expect(shape.count >= 4, "the shape must describe real attributes; got \(shape.count)")
        #expect(Set(shape).count == shape.count, "shape entries must be distinct or two differences could cancel")
        #expect(shape != Array(shape.dropFirst()), "the comparison cannot distinguish a missing attribute")
        #expect(shape.allSatisfy { $0.contains(".") && $0.contains(":") },
                "each entry must carry entity, attribute and type, not just a name")
    }

    /// entity.attribute:type for every attribute, in a stable order.
    private static func shape(of schema: Schema) -> [String] {
        schema.entities
            .sorted { $0.name < $1.name }
            .flatMap { entity in
                entity.attributes
                    .sorted { $0.name < $1.name }
                    .map { "\(entity.name).\($0.name):\($0.valueType)" }
            }
    }
}
