import Foundation
import Testing

@testable import Praxmodoro
import PraxmodoroCore
import PraxmodoroStore

/// Spec: add-session-settings "Autostart behaviour is the user's choice"
/// (tasks 6.1–6.3). Presentation derives from the reconciled engine;
/// persistence materializes when an intent arrives — no UI timer anywhere.
@MainActor
@Suite struct BlockEndFlowTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A clock the test can move. The model only ever reads it.
    private final class Ticker {
        var now: Date
        init(_ start: Date) { now = start }
    }

    private func scratchDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeModel(
        blockEnd: BlockEndBehaviour, autoReturn: Bool = false,
        store: LocalStore? = nil
    ) throws -> (AppModel, Ticker) {
        let ticker = Ticker(t0)
        let model = AppModel(
            store: try store ?? LocalStore(inMemory: true),
            clock: { ticker.now }, defaults: scratchDefaults())
        var rhythm = model.rhythm
        rhythm.blockEnd = blockEnd
        rhythm.autoReturn = autoReturn
        model.setRhythm(rhythm)
        model.policy = .classic
        try model.begin()
        return (model, ticker)
    }

    // MARK: 6.1 — offered default

    @Test func testOfferedDefaultRoutesToBreakAtExpiry() throws {
        let (model, ticker) = try makeModel(blockEnd: .offeredDefault)
        ticker.now = t0.addingTimeInterval(26 * 60)
        #expect(model.effectiveSurface(at: ticker.now) == .onBreak)
        #expect(model.snapshot(at: ticker.now).phase == .onBreak)
    }

    @Test func testOfferedDefaultMaterializesAtTheCanonicalInstant() throws {
        let (model, ticker) = try makeModel(blockEnd: .offeredDefault)
        ticker.now = t0.addingTimeInterval(26 * 60)
        // The first intent after expiry persists the derived history.
        try model.endBreak()
        let events = try model.store!.events(sessionID: model.sessionID!)
        let breakEvent = events.first { $0.kind == .transition && $0.payload == "break" }
        #expect(breakEvent?.at == t0.addingTimeInterval(25 * 60), "break must record at expiry, not at intent time")
        #expect(model.snapshot(at: ticker.now).phase == .running)
    }

    @Test func testMainWindowRoutesThroughEffectiveSurface() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PraxmodoroApp.swift")
        let app = try String(contentsOf: url, encoding: .utf8)
        #expect(app.contains("effectiveSurface"), "main-window routing must derive, not squat on stored surface")
    }

    // MARK: 6.2 — prompt first

    @Test func testPromptFirstOffersInsteadOfBreaking() throws {
        let (model, ticker) = try makeModel(blockEnd: .promptFirst)
        ticker.now = t0.addingTimeInterval(26 * 60)
        #expect(model.effectiveSurface(at: ticker.now) == .focus)
        #expect(model.snapshot(at: ticker.now).phase == .held, "the block completes into a held place")
        #expect(model.blockEndOffer(at: ticker.now), "the gentle offer must be presented")
    }

    @Test func testAcceptingTheOfferStartsTheBreakAtAcceptTime() throws {
        let (model, ticker) = try makeModel(blockEnd: .promptFirst)
        let acceptAt = t0.addingTimeInterval(27 * 60)
        ticker.now = acceptAt
        try model.acceptBlockEndOffer()
        #expect(model.surface == .onBreak)
        let events = try model.store!.events(sessionID: model.sessionID!)
        let held = events.first { $0.kind == .transition && $0.payload == "held" }
        let brk = events.first { $0.kind == .transition && $0.payload == "break" }
        #expect(held?.at == t0.addingTimeInterval(25 * 60), "the expiry-hold records at the canonical instant")
        #expect(brk?.at == acceptAt, "accepting records at accept time")
    }

    @Test func testDismissingTheOfferKeepsTheHeldPlace() throws {
        let (model, ticker) = try makeModel(blockEnd: .promptFirst)
        ticker.now = t0.addingTimeInterval(26 * 60)
        model.dismissBlockEndOffer()
        #expect(model.blockEndOffer(at: ticker.now) == false)
        #expect(model.snapshot(at: ticker.now).phase == .held, "dismissing never loses the place")
        #expect(model.effectiveSurface(at: ticker.now) == .focus)
    }

    @Test func testOfferCopyIsGentle() {
        #expect(!FocusSurface.blockEndOfferText.isEmpty)
        #expect(!FocusSurface.blockEndOfferText.contains("!"))
        for banned in ["now!", "must", "hurry", "expired", "failed"] {
            #expect(!FocusSurface.blockEndOfferText.lowercased().contains(banned))
        }
    }

    // MARK: manual — nothing happens until the user chooses

    @Test func testManualRecordsAndRoutesNothing() throws {
        let (model, ticker) = try makeModel(blockEnd: .manual)
        ticker.now = t0.addingTimeInterval(30 * 60)
        #expect(model.effectiveSurface(at: ticker.now) == .focus)
        #expect(model.snapshot(at: ticker.now).phase == .running)
        #expect(model.blockEndOffer(at: ticker.now) == false)
        #expect(model.snapshot(at: ticker.now).remaining == 0)
    }

    // MARK: auto-return

    @Test func testAutoReturnComesBackToFocusAtTheCanonicalInstant() throws {
        let (model, ticker) = try makeModel(blockEnd: .offeredDefault, autoReturn: true)
        // Past expiry (25:00) and past the break's length (5:00 for classic).
        ticker.now = t0.addingTimeInterval(31 * 60)
        #expect(model.effectiveSurface(at: ticker.now) == .focus)
        let snapshot = model.snapshot(at: ticker.now)
        #expect(snapshot.phase == .running)
        // The new block began at 30:00, so one minute is spent.
        #expect(snapshot.remaining == TimeInterval(24 * 60))
    }

    @Test func testAutoReturnOffLeavesTheBreakOpenEnded() throws {
        let (model, ticker) = try makeModel(blockEnd: .offeredDefault, autoReturn: false)
        ticker.now = t0.addingTimeInterval(3 * 60 * 60)
        #expect(model.snapshot(at: ticker.now).phase == .onBreak)
    }

    @Test func testRelaunchAfterAnAbsenceNeverFillsWithPhantomCycles() throws {
        // Quit five minutes into the block; relaunch three hours later. The
        // expiry backdates honestly, but the absence must not fill with
        // auto-return cycles nobody lived through (design decision 11) —
        // not in the surface, not in the snapshot, and above all not in
        // the store when the first intent materializes.
        let store = try LocalStore(inMemory: true)
        let defaults = scratchDefaults()
        let ticker = Ticker(t0)
        let model = AppModel(store: store, clock: { ticker.now }, defaults: defaults)
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        model.setRhythm(rhythm)
        model.policy = .classic
        try model.begin()

        ticker.now = t0.addingTimeInterval(3 * 60 * 60)
        let relaunched = AppModel(store: store, clock: { ticker.now }, defaults: defaults)
        try relaunched.restore()
        #expect(relaunched.snapshot(at: ticker.now).phase == .onBreak)
        #expect(relaunched.effectiveSurface(at: ticker.now) == .onBreak)

        try relaunched.closeSession()
        let events = try store.events(sessionID: relaunched.sessionID!)
        let running = events.filter { $0.kind == .transition && $0.payload == "running" }
        #expect(running.count == 1, "no focus blocks may materialize during an absence")
    }

    @Test func testRelaunchMidBreakStillHonoursAutoReturn() throws {
        // Relaunch two minutes into a five-minute break: the break's end is
        // witnessed, so the rhythm continues at its canonical instant.
        let store = try LocalStore(inMemory: true)
        let defaults = scratchDefaults()
        let ticker = Ticker(t0)
        let model = AppModel(store: store, clock: { ticker.now }, defaults: defaults)
        var rhythm = model.rhythm
        rhythm.blockEnd = .offeredDefault
        rhythm.autoReturn = true
        model.setRhythm(rhythm)
        model.policy = .classic
        try model.begin()

        // The block expires at 25:00; relaunch at 27:00, mid-break.
        ticker.now = t0.addingTimeInterval(27 * 60)
        let relaunched = AppModel(store: store, clock: { ticker.now }, defaults: defaults)
        try relaunched.restore()
        #expect(relaunched.snapshot(at: ticker.now).phase == .onBreak)
        // Past the break's canonical end, the return fires as witnessed.
        ticker.now = t0.addingTimeInterval(31 * 60)
        #expect(relaunched.snapshot(at: ticker.now).phase == .running)
        #expect(relaunched.effectiveSurface(at: ticker.now) == .focus)
    }

    // MARK: 6.3 — rewind / forward

    @Test func testForwardMinuteIsARecordedAdjustment() throws {
        let (model, ticker) = try makeModel(blockEnd: .promptFirst)
        ticker.now = t0.addingTimeInterval(10 * 60)
        model.forwardMinute()
        #expect(model.snapshot(at: ticker.now).remaining == TimeInterval(16 * 60))
        let events = try model.store!.events(sessionID: model.sessionID!)
        #expect(events.contains { $0.kind == .adjustment && $0.payload == "60" })
    }

    @Test func testRewindMinuteIsARecordedAdjustment() throws {
        let (model, ticker) = try makeModel(blockEnd: .promptFirst)
        ticker.now = t0.addingTimeInterval(10 * 60)
        model.rewindMinute()
        #expect(model.snapshot(at: ticker.now).remaining == TimeInterval(14 * 60))
    }

    @Test func testAdjustmentsSurviveRelaunch() throws {
        let store = try LocalStore(inMemory: true)
        let (model, ticker) = try makeModel(blockEnd: .promptFirst, store: store)
        ticker.now = t0.addingTimeInterval(5 * 60)
        model.forwardMinute()
        model.forwardMinute()

        let relaunched = AppModel(store: store, clock: { ticker.now }, defaults: scratchDefaults())
        try relaunched.restore()
        #expect(relaunched.snapshot(at: ticker.now).remaining == TimeInterval(22 * 60))
    }

    @Test func testAdjustmentOfferedOnlyWhileRunning() throws {
        let (model, ticker) = try makeModel(blockEnd: .promptFirst)
        #expect(model.snapshot(at: ticker.now).offersAdjustment)
        #expect(model.snapshot(at: ticker.now).display.offersAdjustment)
        try model.toggleHold()
        #expect(model.snapshot(at: ticker.now).offersAdjustment == false)
        // Past expiry the controls are absent, not disabled-looking.
        ticker.now = t0.addingTimeInterval(26 * 60)
        #expect(model.snapshot(at: ticker.now).offersAdjustment == false)
    }

    @Test func testAdjustmentHasKeyboardPaths() {
        #expect(KeyboardMap.all["forward-minute"] == "+")
        #expect(KeyboardMap.all["rewind-minute"] == "-")
    }

    @Test func testCompanionActionsCarryTheNudges() {
        var forward = 0
        var rewind = 0
        let actions = CompanionActions(
            forwardMinute: { forward += 1 }, rewindMinute: { rewind += 1 })
        actions.forwardMinute()
        actions.rewindMinute()
        #expect(forward == 1)
        #expect(rewind == 1)
    }
}
