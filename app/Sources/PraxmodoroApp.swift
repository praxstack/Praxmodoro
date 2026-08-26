import AppKit
import PraxmodoroStore
import SwiftUI

@main
struct PraxmodoroApp: App {
    static let capsuleWindowID = "focus-capsule"

    @State private var model: AppModel
    @State private var capsuleOpen = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private var menuBarSurfaceAvailable: Bool {
        model.capabilities.isAvailable(.menuBarSurface)
    }

    private var focusCapsuleAvailable: Bool {
        model.capabilities.isAvailable(.focusCapsule)
    }

    private var returnOverlayAvailable: Bool {
        model.capabilities.isAvailable(.returnOverlay)
    }

    init() {
        // UI tests pass this flag for a hermetic, fresh in-memory store.
        if CommandLine.arguments.contains("-praxmodoro-ephemeral-store") {
            // Window-frame autosave lives in the shared defaults domain, not
            // the store — a capsule frame saved by any earlier run would
            // otherwise restore-create the capsule and fail the
            // "suppressed at launch" assertions. Tests must not inherit the
            // machine's window history.
            if CommandLine.arguments.contains("-praxmodoro-clean-window-state") {
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            }
            self._model = State(initialValue: AppModel(store: try? LocalStore(inMemory: true)))
            return
        }
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Praxmodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let opened = try? LocalStore.open(at: supportDir.appendingPathComponent("praxmodoro.store"), now: Date())
        let model = AppModel(store: opened?.0, recoveryNotice: opened?.1)
        try? model.restore()
        self._model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            // Routing derives from the engine each second — the stored
            // surface corrected by wall-clock truth, so an offered-default
            // block-end presents the break without any UI-side timer
            // advancing state (spec: add-session-settings).
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let snapshot = model.snapshot(at: context.date)
                Group {
                    switch model.effectiveSurface(for: snapshot) {
                    case .initiate: InitiateSurface(model: model)
                    case .focus: FocusSurface(model: model, snapshot: snapshot)
                    case .checkin: CheckinSurface(model: model)
                    case .onBreak: BreakSurface(model: model)
                    case .review: ReviewSurface(model: model)
                    }
                }
                // Every root date edge lets the model materialize canonical
                // transitions before presentation. Phase equality cannot
                // hide a complete focus-break-focus cycle across sleep.
                .onChange(of: context.date) {
                    try? model.observeDerivedPhase(at: context.date)
                }
                .frame(minWidth: 720, minHeight: 520)
                // The way back, over the surface you are coming back to
                // (spec: companion-surfaces "Return overlay presents the exact
                // next action").
                .overlay {
                    if returnOverlayAvailable && model.returnPending {
                        ReturnOverlay(
                            display: snapshot.display,
                            onAcknowledge: { model.acknowledgeReturn() },
                            motionStilledOverride: model.motionStilled ? true : nil)
                    }
                }
            }
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            ) { _ in
                model.handleSystemWake()
            }
            .alert(
                "Local data recovered",
                isPresented: Binding(
                    get: { model.recoveryNotice != nil },
                    set: { if !$0 { model.dismissRecoveryNotice() } }
                )
            ) {
                Button("OK") { model.dismissRecoveryNotice() }
            } message: {
                Text(model.recoveryNotice?.message ?? "")
            }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Check In Now") { try? model.openCheckin() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Focus Capsule") { toggleCapsule() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                // Review was previously reachable only by pointer, which left
                // ⌘N (new session) with no keyboard route to it.
                Button("Close Session") { try? model.closeSession() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                // The in-app half of the motion standdown (spec: focus-loop-ui
                // "…or the user selects 'Motion: still'"). The system setting
                // remains the floor; this only ever adds stillness.
                Button(model.motionToggleLabel) { model.setMotionStilled(!model.motionStilled) }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }

        ({
            if focusCapsuleAvailable {
                return Window("Focus capsule", id: Self.capsuleWindowID) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let snapshot = model.snapshot(at: context.date)
                        FocusCapsule(
                            display: snapshot.display, actions: companionActions,
                            motionStilledOverride: model.motionStilled ? true : nil
                        )
                        .onChange(of: context.date) {
                            try? model.observeDerivedPhase(at: context.date)
                        }
                    }
                    .onReceive(
                        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
                    ) { _ in
                        model.handleSystemWake()
                    }
                    .onDisappear { capsuleOpen = false }
                }
                .windowLevel(.floating)
                .windowStyle(.hiddenTitleBar)
                .windowResizability(.contentSize)
                .defaultLaunchBehavior(.suppressed)
                .restorationBehavior(.disabled)
                .windowBackgroundDragBehavior(.enabled)
            }
            fatalError("validated focus-capsule capability is unavailable")
        })()

        Window("About Praxmodoro", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        // Rhythm, sound, and notification preferences (spec:
        // add-session-settings). ⌘, comes with the scene; opening it never
        // disturbs a running session because preferences live on the
        // defaults seam, not in the session store.
        Settings {
            SettingsSurface(model: model)
        }

        ({
            if menuBarSurfaceAvailable {
                return MenuBarExtra {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let snapshot = model.snapshot(at: context.date)
                        MenuBarPopover(
                            display: snapshot.display, actions: companionActions,
                            motionStilledOverride: model.motionStilled ? true : nil
                        )
                        .onChange(of: context.date) {
                            try? model.observeDerivedPhase(at: context.date)
                        }
                    }
                    .onReceive(
                        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
                    ) { _ in
                        model.handleSystemWake()
                    }
                } label: {
                    Label("Praxmodoro", systemImage: "circle.dotted")
                        .accessibilityLabel("Praxmodoro")
                }
                .menuBarExtraStyle(.window)
            }
            fatalError("validated menu-bar capability is unavailable")
        })()
    }

    /// The capsule's keyboard path: open it, or put it away again.
    ///
    /// The flag tracks the window rather than the keystroke. Closing the
    /// capsule by its own close button used to leave the flag true, so the
    /// next ⌘⇧F dismissed an already-closed window and the shortcut looked
    /// dead (found in review) — `onDisappear` on the scene keeps them in step.
    private func toggleCapsule() {
        if capsuleOpen {
            dismissWindow(id: Self.capsuleWindowID)
            capsuleOpen = false
        } else {
            openWindow(id: Self.capsuleWindowID)
            capsuleOpen = true
        }
    }

    /// One wiring point for every companion surface: they report intent, the
    /// model decides. Surfaces never hold the model themselves.
    private var companionActions: CompanionActions {
        CompanionActions(
            begin: { try? model.begin() },
            toggleHold: { try? model.toggleHold() },
            checkIn: { try? model.openCheckin() },
            endBreak: { try? model.endBreak() },
            openMainWindow: { NSApp.activate(ignoringOtherApps: true) },
            forwardMinute: { model.forwardMinute() },
            rewindMinute: { model.rewindMinute() }
        )
    }
}
