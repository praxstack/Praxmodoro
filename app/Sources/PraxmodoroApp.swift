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
            Group {
                switch model.surface {
                case .initiate: InitiateSurface(model: model)
                case .focus: FocusSurface(model: model)
                case .checkin: CheckinSurface(model: model)
                case .onBreak: BreakSurface(model: model)
                case .review: ReviewSurface(model: model)
                }
            }
            .frame(minWidth: 720, minHeight: 520)
            // The way back, over the surface you are coming back to
            // (spec: companion-surfaces "Return overlay presents the exact
            // next action").
            .overlay {
                if model.returnPending {
                    ReturnOverlay(display: model.snapshot(at: Date()).display) {
                        model.acknowledgeReturn()
                    }
                }
            }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Check In Now") { try? model.openCheckin() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Focus Capsule") { toggleCapsule() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }

        // Always above ordinary windows, never opened for you.
        Window("Focus capsule", id: Self.capsuleWindowID) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                FocusCapsule(display: model.snapshot(at: context.date).display, actions: companionActions)
            }
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

        // The loop, reachable without fronting the app. The popover is a pure
        // function of a snapshot taken here, at the instant it renders
        // (spec: companion-surfaces "Menu-bar popover operates the loop").
        MenuBarExtra("Praxmodoro", systemImage: "circle.dotted") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                MenuBarPopover(display: model.snapshot(at: context.date).display, actions: companionActions)
            }
        }
        .menuBarExtraStyle(.window)
    }

    /// The capsule's keyboard path: open it, or put it away again.
    private func toggleCapsule() {
        if capsuleOpen {
            dismissWindow(id: Self.capsuleWindowID)
        } else {
            openWindow(id: Self.capsuleWindowID)
        }
        capsuleOpen.toggle()
    }

    /// One wiring point for every companion surface: they report intent, the
    /// model decides. Surfaces never hold the model themselves.
    private var companionActions: CompanionActions {
        CompanionActions(
            begin: { try? model.begin() },
            toggleHold: { try? model.toggleHold() },
            checkIn: { try? model.openCheckin() },
            openMainWindow: { NSApp.activate(ignoringOtherApps: true) }
        )
    }
}
