import Foundation
import Testing
@testable import Praxmodoro
import PraxmodoroStore

@MainActor
@Suite struct CheckinTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func startedModel(clock: @escaping () -> Date) throws -> AppModel {
        let model = AppModel(store: try LocalStore(inMemory: true), clock: clock)
        model.taskTitle = "Edit the conference talk outline"
        try model.begin()
        return model
    }

    // Spec: "Check-in with no failure state" — exactly four answers, none of
    // them graded, and the timer holds while the question is open.
    @Test func testFourAnswersNoFailureState() throws {
        #expect(CheckinAnswer.allCases.count == 4)
        let banned = ["fail", "wasted", "behind", "bad", "should have", "only", "just "]
        for answer in CheckinAnswer.allCases {
            let copy = answer.response.lowercased()
            for word in banned {
                #expect(!copy.contains(word), "\(answer) response reads as judgment: \(word)")
            }
        }

        var now = t0
        let model = try startedModel(clock: { now })
        now = t0.addingTimeInterval(600)
        try model.openCheckin()
        #expect(model.surface == .checkin)
        #expect(model.isHeld, "timer must hold while the check-in is open")

        now = t0.addingTimeInterval(660)
        try model.answer(.stillFits)
        #expect(model.surface == .focus)
        #expect(!model.isHeld, "answering resumes the block")

        // The break answer routes to the break surface — also not a failure.
        try model.openCheckin()
        try model.answer(.needBreak)
        #expect(model.surface == .onBreak)
    }

    // Spec: "Check-in never interrupts destructively" — a due check-in waits
    // for the thought-parking field to lose focus before presenting.
    @Test func testCheckinDefersWhileTyping() throws {
        var now = t0
        let model = try startedModel(clock: { now })
        model.thoughtEditingBegan()
        now = t0.addingTimeInterval(600)
        try model.checkinBecameDue()
        #expect(model.surface == .focus, "check-in must not present mid-keystroke")

        try model.thoughtEditingEnded()
        #expect(model.surface == .checkin, "deferred check-in presents on blur")
    }
}
