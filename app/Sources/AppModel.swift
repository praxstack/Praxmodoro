import Foundation
import Observation
import PraxmodoroCore
import PraxmodoroStore

enum Surface: Equatable {
    case initiate, focus, checkin, onBreak, review
}

/// App-level state: routes surfaces, drives the engine with the injected
/// clock, and records every event locally. UI reads; the engine decides.
@MainActor
@Observable
final class AppModel {
    private(set) var surface: Surface = .initiate
    var taskTitle = ""
    var firstAction = ""
    var capacity = "steady"
    var policy: TimingPolicy = .gentleStart
    private(set) var recoveryNotice: RecoveryNotice?

    func dismissRecoveryNotice() {
        recoveryNotice = nil
    }

    /// Increments once per acknowledged user choice; the field blooms on change.
    private(set) var fieldPulse = 0

    // MARK: Motion preference (spec: focus-loop-ui "Reduce Motion or the user
    // selects 'Motion: still' SHALL stop the physics engine")

    private static let motionStilledKey = "praxmodoro.motion-stilled"

    /// The in-app half of the standdown pair. Persisted, because a comfort
    /// choice that resets on relaunch is a nag, not a choice.
    private(set) var motionStilled = false

    func setMotionStilled(_ stilled: Bool) {
        motionStilled = stilled
        defaults.set(stilled, forKey: Self.motionStilledKey)
    }

    /// What the surfaces consume. The system setting is the floor: this app
    /// can add stillness on top of it, never take stillness away from it.
    func fieldIsStilled(systemReduceMotion: Bool) -> Bool {
        systemReduceMotion || motionStilled
    }

    /// The menu item names the state it moves you to, not the one you are in.
    var motionToggleLabel: String {
        motionStilled ? "Motion: gentle" : "Motion: still"
    }

    // MARK: Session settings (spec: add-session-settings). Preferences live
    // on the injected defaults seam and never touch the session store.

    private(set) var rhythm: RhythmPreferences = .factory
    private(set) var sound: SoundPreferences = .factory
    private(set) var notifications: NotificationPreferences = .factory

    func setRhythm(_ preferences: RhythmPreferences) {
        let previousRhythm = rhythm
        let previousPolicy = policy
        rhythm = preferences
        preferences.save(to: defaults)
        reconcilePolicy(after: previousPolicy, previousRhythm: previousRhythm)
        syncSound(at: clock())
    }

    /// Keep the initiation picker valid when presets are edited or removed.
    private func reconcilePolicy(
        after previousPolicy: TimingPolicy,
        previousRhythm: RhythmPreferences
    ) {
        guard !availablePolicies.contains(policy) else { return }
        if previousPolicy.name.hasPrefix("custom:"),
            let remapped = remappedCustomPolicy(from: previousPolicy, previousRhythm: previousRhythm),
            availablePolicies.contains(remapped)
        {
            policy = remapped
            return
        }
        policy = availablePolicies.first ?? .gentleStart
    }

    private func remappedCustomPolicy(
        from previous: TimingPolicy,
        previousRhythm: RhythmPreferences
    ) -> TimingPolicy? {
        guard let prevFocus = previous.focus else { return nil }
        let prevBreak = previous.suggestedBreak
        guard
            let newFocus = mapPresetValue(
                prevFocus,
                from: previousRhythm.focusPresets,
                to: rhythm.focusPresets,
                fallback: TimingPolicy.classic.focus),
            let newBreak = mapPresetValue(
                prevBreak,
                from: previousRhythm.breakPresets,
                to: rhythm.breakPresets,
                fallback: TimingPolicy.classic.suggestedBreak)
        else { return nil }
        return TimingPolicy.custom(
            arrival: previous.arrival, focus: newFocus, suggestedBreak: newBreak)
    }

    private func mapPresetValue(
        _ value: TimeInterval,
        from oldPresets: [TimeInterval],
        to newPresets: [TimeInterval],
        fallback: TimeInterval?
    ) -> TimeInterval? {
        if let index = oldPresets.firstIndex(of: value) {
            guard newPresets.indices.contains(index) else { return nil }
            return newPresets[index]
        }
        if oldPresets.isEmpty, let fallback, value == fallback {
            return newPresets.isEmpty ? fallback : nil
        }
        return nil
    }

    func setSound(_ preferences: SoundPreferences) {
        let volumeChanged = sound.masterVolume != preferences.masterVolume
        sound = preferences
        preferences.save(to: defaults)
        if volumeChanged {
            soundScheduler.setChimeVolume(preferences.masterVolume)
            for (cue, running) in tickState where running {
                soundScheduler.setTickLoop(cue, running: true, volume: preferences.masterVolume)
            }
        }
        syncSound(at: clock())
    }

    func previewSound(_ cue: SoundCue) {
        soundScheduler.scheduleChime(cue, at: clock(), volume: sound.masterVolume)
    }

    func handleSystemWake() {
        soundScheduler.cancelExpiredChimes(at: clock())
        skipPastBlockStartOnNextSync = true
    }

    // MARK: Sound direction (spec: "Sound cues, all optional"). Pure policy
    // over the same derived state the surfaces render; the scheduler seam
    // owns the audio machinery. Called after every intent, so cues follow
    // transitions — nothing here runs on a schedule.

    /// The render loop's hand-off: when routing observes a derived phase
    /// change (expiry, autostart, auto-return), it lets the model bring
    /// sound and notifications in line. Presentation only — the session is
    /// never touched here, so the one-clock rule stands (finding 3).
    func syncPresentation(at now: Date) {
        syncSound(at: now)
    }

    /// Record every canonical transition visible at this root-render
    /// instant, then align presentation. Date edges matter even when the
    /// phase before and after a full focus-break-focus cycle is `.running`.
    func observeDerivedPhase(at now: Date) throws {
        try materialize(at: now)
        syncSound(at: now)
    }

    /// Everything the initiation surface may offer: the four built-ins plus
    /// every user preset as a real policy (validator finding 1).
    var availablePolicies: [TimingPolicy] {
        let builtIns: [TimingPolicy] = [.gentleStart, .classic, .flow, .recoveryFirst]
        guard !rhythm.focusPresets.isEmpty || !rhythm.breakPresets.isEmpty else { return builtIns }

        let focuses =
            rhythm.focusPresets.isEmpty
            ? [TimingPolicy.classic.focus].compactMap { $0 }
            : rhythm.focusPresets
        let breaks =
            rhythm.breakPresets.isEmpty
            ? [TimingPolicy.classic.suggestedBreak]
            : rhythm.breakPresets
        var seen = Set<TimingPolicy>()
        let custom = focuses.flatMap { focus in
            breaks.map { TimingPolicy.custom(arrival: nil, focus: focus, suggestedBreak: $0) }
        }.filter {
            seen.insert($0).inserted
        }
        return builtIns + custom
    }

    /// Minutes of the cadence's longer break, when this break is the Nth —
    /// nil otherwise. The break surface presents it as a suggestion with
    /// ordinary decline (validator finding 7).
    /// Surface-facing flavour: reads the injected clock so no view touches
    /// the wall clock (surface guard).
    var longBreakMinutesDueNow: Int? { longBreakMinutesDue(at: clock()) }

    func longBreakMinutesDue(at now: Date) -> Int? {
        guard let cadence = rhythm.cadence, let session else { return nil }
        let reconciled = reconciledSession(session, at: now)
        guard reconciled.state(at: now) == .onBreak else { return nil }
        guard reconciled.suggestedBreakLength(cadence: cadence) == cadence.length else { return nil }
        return Int(cadence.length / 60)
    }

    private var tickState: [SoundCue: Bool] = [:]
    private var scheduledChime: (cue: SoundCue, at: Date)?
    private var pendingBlockStartAt: Date?
    /// Suppresses one retro block-start after wake cancelled expired chimes.
    private var skipPastBlockStartOnNextSync = false

    private func syncSound(at now: Date) {
        let phase = snapshot(at: now).phase

        let desiredTicks: [(cue: SoundCue, on: Bool)] = [
            (.focusTick, sound.tickLoop && sound.focusTick && phase == .running),
            (.breakTick, sound.tickLoop && sound.breakTick && phase == .onBreak),
        ]
        // Stops before starts, in a fixed order: a phase handover silences
        // the old loop before the new one begins, deterministically.
        for (cue, on) in desiredTicks where !on && tickState[cue, default: false] {
            soundScheduler.setTickLoop(cue, running: false, volume: sound.masterVolume)
            tickState[cue] = false
        }
        for (cue, on) in desiredTicks where on && !tickState[cue, default: false] {
            soundScheduler.setTickLoop(cue, running: true, volume: sound.masterVolume)
            tickState[cue] = true
        }

        // One pending chime at a time, always for a strictly future canonical
        // instant — an expiry already past never retro-fires.
        var desired: (cue: SoundCue, at: Date)?
        if let session {
            let reconciled = reconciledSession(session, at: now)
            if sound.focusEndChime, let expiry = reconciled.expiryInstant(), expiry > now {
                desired = (.focusEnd, expiry)
            } else if sound.breakEndChime,
                let breakEnd = reconciled.breakEndInstant(cadence: rhythm.cadence)
            {
                if breakEnd > now { desired = (.breakEnd, breakEnd) }
            }
        }
        if scheduledChime?.cue != desired?.cue || scheduledChime?.at != desired?.at {
            if let scheduledChime, scheduledChime.at > now {
                soundScheduler.cancelScheduledChime(scheduledChime.cue, at: scheduledChime.at)
            }
            if let desired {
                soundScheduler.scheduleChime(desired.cue, at: desired.at, volume: sound.masterVolume)
            }
            scheduledChime = desired
        }
        if let instant = pendingBlockStartAt {
            pendingBlockStartAt = nil
            let past = instant <= now
            if sound.blockStart, !(past && skipPastBlockStartOnNextSync) {
                soundScheduler.scheduleChime(.blockStart, at: instant, volume: sound.masterVolume)
            }
        }
        skipPastBlockStartOnNextSync = false
        syncNotifications(at: now)
    }

    func setNotifications(_ preferences: NotificationPreferences) {
        let firstEnable =
            (preferences.blockEndEnabled || preferences.breakEndEnabled)
            && !(notifications.blockEndEnabled || notifications.breakEndEnabled)
        notifications = preferences
        preferences.save(to: defaults)
        // The system dialog appears at the moment the user asks for
        // notifications, never at launch (validator finding 2).
        if firstEnable { refreshNotificationAvailability() }
        syncNotifications(at: clock())
    }

    // MARK: Notification direction (spec: "Local notifications with honest
    // text"). Same shape as sound: one pending request, anchored on a
    // canonical instant, cancelled the moment the derivation changes.

    /// Plain truth for the panes: the system has denied delivery.
    private(set) var notificationsUnavailable = false
    private var scheduledNotification: LocalNotificationRequest?

    func refreshNotificationAvailability() {
        notificationScheduler.checkAvailability { [weak self] availability in
            guard let self else { return }
            self.notificationsUnavailable = availability == .denied
            self.syncNotifications(at: self.clock())
        }
    }

    private func syncNotifications(at now: Date) {
        var desired: LocalNotificationRequest?
        if !notificationsUnavailable, let session {
            let reconciled = reconciledSession(session, at: now)
            if notifications.blockEndEnabled, let expiry = reconciled.expiryInstant(), expiry > now {
                desired = LocalNotificationRequest(
                    id: "block-end", body: notifications.blockEndText, at: expiry,
                    bringToFront: notifications.bringToFront)
            } else if notifications.breakEndEnabled,
                let breakEnd = reconciled.breakEndInstant(cadence: rhythm.cadence)
            {
                if breakEnd > now {
                    desired = LocalNotificationRequest(
                        id: "break-end", body: notifications.breakEndText, at: breakEnd,
                        bringToFront: notifications.bringToFront)
                }
            }
        }
        guard desired != scheduledNotification else { return }
        if scheduledNotification != nil {
            notificationScheduler.cancelPending()
        }
        if let desired {
            notificationScheduler.schedule(desired)
        }
        scheduledNotification = desired
    }

    private(set) var session: Session?
    private(set) var sessionID: UUID?
    private(set) var parkedThoughts: [String] = []

    let store: LocalStore?
    let capabilities: CapabilityRegistry
    private let clock: () -> Date
    private let liveObservationStartedAt: Date
    private let defaults: UserDefaults
    private let soundScheduler: SoundCueScheduling
    private let notificationScheduler: NotificationScheduling

    init(
        store: LocalStore?,
        recoveryNotice: RecoveryNotice? = nil,
        capabilities: CapabilityRegistry = CapabilityRegistry(configuredKeys: Set(FeatureKey.allCases)),
        clock: @escaping () -> Date = { Date() }, defaults: UserDefaults = .standard,
        soundScheduler: SoundCueScheduling = AudioCueScheduler(),
        notificationScheduler: NotificationScheduling = LocalNotificationScheduler()
    ) {
        self.store = store
        self.recoveryNotice = recoveryNotice
        self.capabilities = capabilities
        self.clock = clock
        self.liveObservationStartedAt = clock()
        self.defaults = defaults
        self.soundScheduler = soundScheduler
        self.notificationScheduler = notificationScheduler
        self.motionStilled = defaults.bool(forKey: Self.motionStilledKey)
        self.rhythm = RhythmPreferences.load(from: defaults)
        self.sound = SoundPreferences.load(from: defaults)
        self.notifications = NotificationPreferences.load(from: defaults)
        // Spec: startup validation fails fast in debug; lookup self-heals in release.
        do { try capabilities.validate() } catch { assertionFailure("capability validation failed: \(error)") }
        // A returning user's denial state refreshes at launch; a fresh
        // install with nothing enabled is never prompted (finding 2).
        if notifications.blockEndEnabled || notifications.breakEndEnabled {
            refreshNotificationAvailability()
        }
    }

    private func appendTransition(_ state: SessionState, at instant: Date) throws {
        let payload = try TransitionPayload.encode(state)
        guard let id = sessionID else { return }
        try store?.appendEvent(sessionID: id, kind: .transition, payload: payload, at: instant)
    }

    func begin() throws {
        fieldPulse += 1
        lastCheckinResponse = nil
        let now = clock()
        var newSession = Session(policy: policy, startedAt: now)
        try newSession.apply(.begin, at: now)
        session = newSession
        let id = UUID()
        sessionID = id
        surface = .focus
        try store?.createSession(id: id, policyName: policy.name, startedAt: now)
        try store?.saveTask(sessionID: id, title: taskTitle, firstAction: firstAction, at: now)
        try appendTransition(.running, at: now)
        if !capacity.isEmpty {
            try store?.appendEvent(sessionID: id, kind: .capacityReport, payload: capacity, at: now)
        }
        pendingBlockStartAt = now
        syncSound(at: now)
    }

    /// Relaunch lands the user exactly where they were: rebuild the session
    /// purely from persisted transitions and adjustments (spec: app-scaffold
    /// lifecycle). Sorted by timestamp because materialized records are
    /// backdated to canonical instants, not appended in wall-clock order.
    func restore() throws {
        guard let store, let summary = try store.latestSession() else { return }
        let events = try store.events(sessionID: summary.id)
        let task = try store.task(sessionID: summary.id)
        let result = try SessionReplay(summary: summary).replay(events: events, task: task)
        guard result.session.transitions.last?.state != .closed else { return }

        session = result.session
        sessionID = result.sessionID
        policy = result.session.policy
        taskTitle = result.taskTitle
        firstAction = result.firstAction
        parkedThoughts = result.parkedThoughts

        // Auto-return is deliberately absent here (design decision 10): an
        // absence must not fill with focus blocks nobody lived through.
        let now = clock()
        switch result.session.reconciled(
            at: now, blockEnd: rhythm.blockEnd, autoReturn: false, autoReturnAfter: nil
        ).state(at: now) {
        case .running, .held: surface = .focus
        case .onBreak: surface = .onBreak
        default: surface = .initiate
        }
        syncSound(at: now)
    }

    // MARK: Block-end flow (spec: add-session-settings "Autostart behaviour
    // is the user's choice"). Presentation derives from the reconciled
    // engine; persistence materializes when an intent arrives.

    /// The one reconciliation every read and intent goes through: the user's
    /// block-end behaviour, and — while the app is alive to witness it — the
    /// auto-return rhythm with the cadence-aware break length.
    private func reconciledSession(_ session: Session, at now: Date) -> Session {
        session.reconciled(
            at: now, blockEnd: rhythm.blockEnd,
            autoReturn: rhythm.autoReturn,
            autoReturnAfter: rhythm.autoReturn ? liveObservationStartedAt : nil,
            cadence: rhythm.cadence)
    }

    /// Derived routing for the main window: the stored surface, corrected by
    /// what the engine says this instant. Pure — rendering never mutates.
    func effectiveSurface(at now: Date) -> Surface {
        effectiveSurface(for: snapshot(at: now))
    }

    func effectiveSurface(for snapshot: SessionSnapshot) -> Surface {
        guard surface == .focus || surface == .onBreak else { return surface }
        switch snapshot.phase {
        case .onBreak where surface == .focus: return .onBreak
        case .running where surface == .onBreak: return .focus
        default: return surface
        }
    }

    /// Persist whatever reconciliation has derived, so the stored history
    /// catches up with presented truth before an intent lands on it.
    private func materialize(at now: Date) throws {
        guard let current = session else { return }
        let reconciled = reconciledSession(current, at: now)
        // Structural diff, not a keyed one: the arrays are small and
        // TransitionRecord equality already covers instant + state.
        let fresh = reconciled.transitions.filter { !current.transitions.contains($0) }
        guard !fresh.isEmpty else { return }
        for record in fresh {
            try appendTransition(record.state, at: record.at)
            // A materialized return FROM A BREAK greets like any other
            // return. A promotion also materializes as .running but its
            // predecessor is running — promotions are seamless, never a
            // comeback (validator finding 5).
            if record.state == .running,
                let index = reconciled.transitions.firstIndex(of: record), index > 0,
                reconciled.transitions[index - 1].state == .onBreak
            {
                returnPending = true
                pendingBlockStartAt = record.at
            }
        }
        session = reconciled
        blockEndOfferDismissed = false
    }

    /// True while the prompt-first offer should present: the block is
    /// complete, the place is held, and the user has not waved it away.
    private var blockEndOfferDismissed = false

    func blockEndOffer(at now: Date) -> Bool {
        snapshot(at: now).offersBlockEndPrompt
    }

    /// Accepting the offer records the break at accept time — the engine
    /// held the place at the canonical expiry instant already.
    func acceptBlockEndOffer() throws {
        let now = clock()
        try materialize(at: now)
        guard var current = session, current.state(at: now) == .held else { return }
        fieldPulse += 1
        try current.apply(.startBreak, at: now)
        session = current
        try appendTransition(.onBreak, at: now)
        surface = .onBreak
        syncSound(at: now)
    }

    /// Waving the offer away costs nothing and loses nothing: the place
    /// stays held until the user chooses.
    func dismissBlockEndOffer() {
        blockEndOfferDismissed = true
    }

    // MARK: Rewind / forward (spec: "Rewind and forward as recorded
    // adjustments"). ±1 minute, an engine event, never a mutation.

    func forwardMinute() {
        nudge(60)
    }

    func rewindMinute() {
        nudge(-60)
    }

    private func nudge(_ delta: TimeInterval) {
        let now = clock()
        guard var current = session else { return }
        do {
            try materialize(at: now)
            current = session ?? current
            try current.applyAdjustment(delta, at: now)
            session = current
            if let id = sessionID {
                try store?.appendEvent(sessionID: id, kind: .adjustment, payload: "\(Int(delta))", at: now)
            }
            fieldPulse += 1
            syncSound(at: now)
        } catch {
            // A rejected nudge (not running, already expired) changes nothing.
        }
    }

    /// Capture without changing context (spec: thought parking).
    func parkThought(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        parkedThoughts.append(trimmed)
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .thoughtParked, payload: trimmed, at: clock())
        }
        // Surface intentionally untouched — focus stays active.
    }

    /// The user's hold/resume. Pulses, because pressing it is a choice.
    func toggleHold() throws {
        fieldPulse += 1
        try applyHoldToggle()
    }

    /// The mechanics, shared with internal transitions that hold or resume as
    /// a side effect (opening a check-in, returning from an answer). Those are
    /// not user choices and must not pulse — the M1 pulse test pins exactly
    /// one bloom per answered check-in.
    private func applyHoldToggle() throws {
        let now = clock()
        try materialize(at: now)
        guard var current = session else { return }
        let state = current.state(at: now)
        let intent: SessionIntent = state == .held ? .resume : .hold
        try current.apply(intent, at: now)
        session = current
        try appendTransition(current.state(at: now), at: now)
        syncSound(at: now)
    }

    // MARK: Check-in (spec: no failure state; never interrupts destructively)

    private(set) var checkinPending = false
    private(set) var isEditingThought = false
    private(set) var lastCheckinResponse: String?

    /// Open the check-in: the timer holds while the question is open.
    ///
    /// A pending return card stays visible. The check-in holds once and waits
    /// behind it, so two requests never compete for attention.
    func openCheckin() throws {
        if returnPending {
            if !isHeld { try applyHoldToggle() }
            checkinPending = true
            return
        }
        if !isHeld { try applyHoldToggle() }
        surface = .checkin
    }

    /// A due check-in defers while the user is mid-keystroke in thought
    /// parking; it presents when the field loses focus.
    func checkinBecameDue() throws {
        if isEditingThought {
            checkinPending = true
        } else {
            try openCheckin()
        }
    }

    func thoughtEditingBegan() { isEditingThought = true }

    func thoughtEditingEnded() throws {
        isEditingThought = false
        if checkinPending {
            checkinPending = false
            try openCheckin()
        }
    }

    func answer(_ answer: CheckinAnswer) throws {
        fieldPulse += 1
        lastCheckinResponse = answer.response
        let now = clock()
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .checkinAnswer, payload: answer.rawValue, at: now)
        }
        switch answer {
        case .stillFits, .smallerStep, .drifted:
            if isHeld { try applyHoldToggle() }
            surface = .focus
        case .needBreak:
            guard var current = session else { return }
            try current.apply(.startBreak, at: now)
            session = current
            try appendTransition(.onBreak, at: now)
            surface = .onBreak
        }
        syncSound(at: now)
    }

    // MARK: Break (spec: user-steerable, held place, ending early is ordinary)

    /// Suggestion derived only from what the user reported — never from a
    /// claim about what is optimal. Pure over reported inputs, so early break
    /// ends can never alter future suggestion weight.
    var breakSuggestion: String {
        switch capacity {
        case "restless": "Stretch — unclench the jaw, drop the shoulders."
        case "foggy": "Water — stand, pour, sip slowly."
        case "charged": "Step away — a doorway or a window counts."
        default: "Quiet — no prompt, just the held place."
        }
    }

    var breakSuggestionProvenance: String {
        "You said “\(capacity)”, so this suggestion came first. This pattern is editable and can be turned off entirely."
    }

    /// The re-entry card: the exact next action, waiting for the return.
    var reentryStep: String { firstAction }

    func chooseBreak(_ choice: String) throws {
        fieldPulse += 1
        if let id = sessionID {
            try store?.appendEvent(sessionID: id, kind: .breakChoice, payload: choice, at: clock())
        }
    }

    /// True from the moment a break ends until the user acknowledges the
    /// return overlay. Presentation only: deliberately not persisted and
    /// deliberately not an event, because acknowledging a card is not
    /// something that happened to the session (design decision 3).
    private(set) var returnPending = false

    /// Dismiss the return overlay. Changes nothing about the session.
    func acknowledgeReturn() {
        guard returnPending else { return }
        returnPending = false
        if checkinPending {
            checkinPending = false
            if let session, session.state(at: clock()) != .closed {
                surface = .checkin
            }
        }
        fieldPulse += 1
    }

    /// Ending a break — at any moment — is ordinary: resume and return to
    /// focus with no notice, penalty, or record beyond the transition itself.
    func endBreak() throws {
        let now = clock()
        try materialize(at: now)
        guard var current = session else { return }
        try current.apply(.endBreak, at: now)
        session = current
        try appendTransition(.running, at: now)
        surface = .focus
        returnPending = true
        pendingBlockStartAt = now
        syncSound(at: now)
    }

    // MARK: Review (spec: a record, not a verdict)

    struct TimelineEntry: Equatable {
        let at: Date
        let label: String
    }

    func closeSession() throws {
        let now = clock()
        try materialize(at: now)
        guard var current = session else { return }
        try current.apply(.close, at: now)
        session = current
        try appendTransition(.closed, at: now)
        returnPending = false
        checkinPending = false
        surface = .review
        syncSound(at: now)
    }

    func beginNextSession() {
        surface = .initiate
    }

    /// Descriptive timeline straight from the event log — what happened,
    /// never how well.
    func reviewTimeline() throws -> [TimelineEntry] {
        guard let id = sessionID, let store else { return [] }
        return try store.events(sessionID: id).map { event in
            let label: String
            switch event.kind {
            case .transition:
                label = TransitionPayload.reviewLabel(for: event.payload)
            case .checkinAnswer:
                label = "Check-in: \(CheckinAnswer(rawValue: event.payload)?.label ?? event.payload)"
            case .thoughtParked: label = "Parked a thought"
            case .breakChoice: label = "Break: \(event.payload)"
            case .capacityReport: label = "Reported capacity: \(event.payload)"
            case .edit: label = "Edited a note"
            case .clockAnomaly: label = "Clock changed — time kept honest"
            case .adjustment:
                label = (Int(event.payload) ?? 0) >= 0 ? "Gave the block a minute" : "Took a minute back"
            }
            return TimelineEntry(at: event.at, label: label)
        }
    }

    /// Uncertainty-aware, non-diagnostic insight. Single-session data always
    /// states its limits (spec: "Single-day observations stay tentative").
    var reviewInsight: String {
        let resized = (try? reviewTimeline())?.contains { $0.label.contains("smaller") } ?? false
        let base =
            resized
            ? "Making the step smaller kept things moving today."
            : "You stayed with the loop today."
        return base + " One session is not a pattern — the options simply stay offered."
    }

    // MARK: The canonical projection every surface renders

    /// Project the engine into everything a surface may legitimately show, at
    /// one instant. Surfaces call this and render the result; they never hold,
    /// count, or format time themselves (spec: companion-surfaces "One
    /// canonical session state for every surface").
    func snapshot(at now: Date) -> SessionSnapshot {
        guard let session else {
            return SessionSnapshot(
                phase: .idle,
                taskLine: taskTitle,
                nextAction: firstAction,
                remaining: nil,
                remainingText: nil,
                statusLine: Self.statusLine(for: .idle),
                accessibilitySummary: "Companion: resting",
                offersAdjustment: false,
                offersBlockEndPrompt: false
            )
        }
        let reconciled = reconciledSession(session, at: now)
        let phase = SessionSnapshot.Phase(reconciled.state(at: now))
        let remaining = reconciled.remaining(at: now)
        return SessionSnapshot(
            phase: phase,
            taskLine: taskTitle,
            nextAction: firstAction,
            remaining: remaining,
            remainingText: remaining.map(SessionSnapshot.clockFace) ?? "open",
            statusLine: Self.statusLine(for: phase),
            accessibilitySummary: Self.fieldSummary(phase: phase, remaining: remaining),
            offersAdjustment: phase == .running && remaining.map { $0 > 0 } ?? false,
            offersBlockEndPrompt: rhythm.blockEnd == .promptFirst && !blockEndOfferDismissed
                && phase == .held && remaining == 0
        )
    }

    private static func statusLine(for phase: SessionSnapshot.Phase) -> String {
        switch phase {
        case .idle: "Ready when you are"
        case .running: "Focusing"
        case .held: "Held — your place is kept"
        case .onBreak: "Resting, place kept"
        case .closed: "Session closed"
        }
    }

    private static func fieldSummary(phase: SessionSnapshot.Phase, remaining: TimeInterval?) -> String {
        if phase == .held { return "Companion: holding your place" }
        guard let remaining else { return "Companion: breathing, open-ended block" }
        let minutes = Int((remaining / 60).rounded())
        return "Companion: breathing, \(minutes) minute\(minutes == 1 ? "" : "s") remaining"
    }

    // MARK: Accessibility (spec: VoiceOver reads a concise field summary)

    func fieldAccessibilitySummary(at now: Date) -> String {
        snapshot(at: now).accessibilitySummary
    }

    var isHeld: Bool {
        guard let session else { return false }
        let now = clock()
        return reconciledSession(session, at: now).state(at: now) == .held
    }

    /// Remaining time is derived through the engine — the view never counts.
    func remaining(at now: Date) -> TimeInterval? {
        guard let session else { return nil }
        return reconciledSession(session, at: now).remaining(at: now)
    }
}
