import Foundation
import Testing

@testable import Praxmodoro
import PraxmodoroCore
import PraxmodoroStore

/// Spec: add-session-settings "Local notifications with honest text"
/// (tasks 8.1–8.4). Scheduling anchors on canonical instants through a seam;
/// the user's words travel verbatim; denied permission degrades quietly.
@MainActor
@Suite struct NotificationDirectorTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private final class Ticker {
        var now: Date
        init(_ start: Date) { now = start }
    }

    private final class NotificationRecorder: NotificationScheduling {
        var scheduled: [LocalNotificationRequest] = []
        var cancels = 0
        var availability = NotificationAvailability.available

        func schedule(_ request: LocalNotificationRequest) {
            scheduled.append(request)
        }

        func cancelPending() {
            cancels += 1
        }

        func checkAvailability(_ report: @escaping @MainActor (NotificationAvailability) -> Void) {
            let value = availability
            Task { @MainActor in report(value) }
        }
    }

    private func scratchDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeModel(
        _ mutate: (inout NotificationPreferences) -> Void = { _ in }
    ) throws -> (AppModel, Ticker, NotificationRecorder) {
        let ticker = Ticker(t0)
        let recorder = NotificationRecorder()
        let model = AppModel(
            store: try LocalStore(inMemory: true), clock: { ticker.now },
            defaults: scratchDefaults(), soundScheduler: InertSoundScheduler(),
            notificationScheduler: recorder)
        var prefs = model.notifications
        mutate(&prefs)
        model.setNotifications(prefs)
        model.policy = .classic
        return (model, ticker, recorder)
    }

    // MARK: 8.1 — canonical scheduling, cancel on change

    @Test func testDisabledByFactorySchedulesNothing() throws {
        let (model, ticker, recorder) = try makeModel()
        try model.begin()
        ticker.now = t0.addingTimeInterval(5 * 60)
        model.forwardMinute()
        #expect(recorder.scheduled.isEmpty)
    }

    @Test func testBlockEndNotificationAnchorsOnExpiry() throws {
        let (model, _, recorder) = try makeModel { $0.blockEndEnabled = true }
        try model.begin()
        #expect(recorder.scheduled.count == 1)
        #expect(recorder.scheduled.first?.at == t0.addingTimeInterval(25 * 60))
        #expect(recorder.scheduled.first?.body == NotificationPreferences.defaultBlockEndText)
    }

    @Test func testAdjustmentAndHoldRescheduleOrCancel() throws {
        let (model, ticker, recorder) = try makeModel { $0.blockEndEnabled = true }
        try model.begin()
        ticker.now = t0.addingTimeInterval(10 * 60)
        model.forwardMinute()
        #expect(recorder.cancels >= 1)
        #expect(recorder.scheduled.last?.at == t0.addingTimeInterval(26 * 60))
        try model.toggleHold()
        #expect(recorder.cancels >= 2, "a held block has no expiry to announce")
    }

    @Test func testSettingChangeCancelsPending() throws {
        let (model, _, recorder) = try makeModel { $0.blockEndEnabled = true }
        try model.begin()
        model.setNotifications(.factory)
        #expect(recorder.cancels >= 1)
    }

    @Test func testBringToFrontRidesTheRequest() throws {
        let (model, _, recorder) = try makeModel {
            $0.blockEndEnabled = true
            $0.bringToFront = true
        }
        try model.begin()
        #expect(recorder.scheduled.first?.bringToFront == true)
    }

    // MARK: 8.2 / 8.3 — shipped text is linted, user text is verbatim

    @Test func testShippedDefaultsAreGentle() {
        // CopyToneTests lints every shipped literal; this pins the two
        // notification defaults specifically so a reword cannot dodge it.
        let banned = ["must", "hurry", "expired", "failed", "!"]
        for text in [NotificationPreferences.defaultBlockEndText, NotificationPreferences.defaultBreakEndText] {
            for term in banned {
                #expect(!text.lowercased().contains(term), "shipped default carries urgency: \(text)")
            }
        }
    }

    @Test func testUserTextTravelsVerbatim() throws {
        let raw = "GET UP!! stretch — you promised (proven optimal schedule)"
        let (model, _, recorder) = try makeModel {
            $0.blockEndEnabled = true
            $0.blockEndText = raw
        }
        try model.begin()
        #expect(recorder.scheduled.first?.body == raw, "the user's words are theirs, character for character")
    }

    // MARK: 8.4 — denied permission degrades quietly

    @Test func testDeniedPermissionSchedulesNothingAndSaysSo() async throws {
        let (model, _, recorder) = try makeModel { $0.blockEndEnabled = true }
        recorder.availability = .denied
        model.refreshNotificationAvailability()
        // The seam reports back through the main actor; yield to let it land.
        await Task.yield()
        try model.begin()
        #expect(recorder.scheduled.isEmpty, "denied permission must schedule nothing")
        #expect(model.notificationsUnavailable, "the panes need the plain truth to render")
    }

    @Test func testNoReAuthorizationNagPathExists() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources/NotificationDirector.swift"),
            encoding: .utf8)
        // The system dialog may be requested exactly once (the OS itself
        // never re-shows it); any second call site is a nag path.
        let callSites = source.components(separatedBy: "requestAuthorization").count - 1
        #expect(callSites <= 1, "more than one authorization call site is a nag path")
    }
}

/// A silent stand-in so notification tests exercise one seam at a time.
private struct InertSoundScheduler: SoundCueScheduling {
    func scheduleChime(_ cue: SoundCue, at instant: Date, volume: Double) {}
    func cancelScheduledChimes() {}
    func setTickLoop(_ cue: SoundCue, running: Bool, volume: Double) {}
}
