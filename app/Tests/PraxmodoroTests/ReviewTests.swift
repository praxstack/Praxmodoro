import Foundation
import Testing
@testable import Praxmodoro
import PraxmodoroStore

@MainActor
@Suite struct ReviewTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // Spec: "Review is a record, not a verdict" + "Single-day observations
    // stay tentative" — insight copy from one day of data states its limits.
    @Test func testSingleDayInsightStatesLimits() throws {
        var now = t0
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the conference talk outline"
        try model.begin()
        now = t0.addingTimeInterval(600)
        try model.openCheckin()
        try model.answer(.smallerStep)
        now = t0.addingTimeInterval(45 * 60)
        try model.closeSession()

        #expect(model.surface == .review)
        let insight = model.reviewInsight.lowercased()
        #expect(insight.contains("not a pattern") || insight.contains("one afternoon") || insight.contains("one session"))

        // The timeline reproduces the recorded events in order, descriptively.
        let timeline = try model.reviewTimeline()
        #expect(timeline.count >= 3)
        #expect(timeline.first?.at == t0)
        let banned = ["failed", "wasted", "score", "grade", "productivity"]
        for entry in timeline {
            for word in banned {
                #expect(!entry.label.lowercased().contains(word), "verdict language in timeline: \(word)")
            }
        }
    }
}
