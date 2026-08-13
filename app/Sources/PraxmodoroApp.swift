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

    init() {
        // UI tests pass this flag for a hermetic, fresh in-memory store.
        if CommandLine.arguments.contains("-praxmodoro-ephemeral-store") {
            self._model = State(initialValue: AppModel(store: try? LocalStore(inMemory: true)))
            return
        }
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Praxmodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let opened = try? LocalStore.open(at: supportDir.appendingPathComponent("praxmodoro.store"), now: Date())
        let model = AppModel(store: opened?.0)
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
                Group {
                    switch model.effectiveSurface(at: context.date) {
                    case .initiate: InitiateSurface(model: model)
                    case .focus: FocusSurface(model: model)
                    case .checkin: CheckinSurface(model: model)
                    case .onBreak: BreakSurface(model: model)
                    case .review: ReviewSurface(model: model)
                    }
                }
                // A derived phase change (expiry, autostart, auto-return)
                // hands presentation — sound and notifications only, never
                // session state — back to the model. Rendering itself stays
                // pure; this fires only on the transition edge.
                .onChange(of: model.snapshot(at: context.date).phase) {
                    model.syncPresentation(at: context.date)
                }
            }
            .frame(minWidth: 720, minHeight: 520)
            // The way back, over the surface you are coming back to
            // (spec: companion-surfaces "Return overlay presents the exact
            // next action").
            .overlay {
                if model.returnPending {
                    ReturnOverlay(
                        display: model.snapshot(at: Date()).display,
                        onAcknowledge: { model.acknowledgeReturn() },
                        motionStilledOverride: model.motionStilled ? true : nil)
                }
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

        // Always above ordinary windows, never opened for you.
        Window("Focus capsule", id: Self.capsuleWindowID) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                FocusCapsule(
                    display: model.snapshot(at: context.date).display, actions: companionActions,
                    motionStilledOverride: model.motionStilled ? true : nil)
            }
            .onDisappear { capsuleOpen = false }
        }
        .windowLevel(.floating)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .windowBackgroundDragBehavior(.enabled)

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

        // The loop, reachable without fronting the app. The popover is a pure
        // function of a snapshot taken here, at the instant it renders
        // (spec: companion-surfaces "Menu-bar popover operates the loop").
        MenuBarExtra("Praxmodoro", systemImage: "circle.dotted") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                MenuBarPopover(
                    display: model.snapshot(at: context.date).display, actions: companionActions,
                    motionStilledOverride: model.motionStilled ? true : nil)
            }
        }
        .menuBarExtraStyle(.window)
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
