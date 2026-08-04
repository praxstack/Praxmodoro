import SwiftUI

/// What a companion surface may ask for. Closures keep these surfaces pure:
/// they render a snapshot and report intent, and never reach for the model —
/// which is what makes a locally-aged clock impossible rather than merely
/// forbidden (spec: companion-surfaces "No surface counts time").
@MainActor
struct CompanionActions {
    var begin: () -> Void = {}
    var toggleHold: () -> Void = {}
    var checkIn: () -> Void = {}
    var openMainWindow: () -> Void = {}

    /// For tests and previews: renders the surface without wiring anything.
    static let inert = CompanionActions()
}

/// The loop, reachable from the menu bar without fronting the app.
struct MenuBarPopover: View {
    let snapshot: SessionSnapshot
    let actions: CompanionActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var statusText: String { snapshot.statusLine }

    /// nil when there is no session — the popover then renders no clock at
    /// all rather than a zero (spec: "Popover with no session").
    var timeText: String? { snapshot.remainingText }

    var primaryControlLabel: String {
        switch snapshot.phase {
        case .idle, .closed: "Begin"
        case .running: "Hold"
        case .held: "Resume"
        case .onBreak: "Back to focus"
        }
    }

    var accessibilityLabel: String {
        guard let timeText else { return "Praxmodoro: \(statusText)" }
        return "Praxmodoro: \(statusText), \(timeText) left"
    }

    /// The rendered catalog for this phase; tests pin its shape.
    var controls: [String] {
        guard snapshot.hasSession else {
            return ["popover-status", "popover-primary", "popover-open-main"]
        }
        return ["popover-status", "popover-time", "popover-task", "popover-primary", "popover-check-in", "popover-open-main"]
    }

    private func primaryAction() {
        switch snapshot.phase {
        case .idle, .closed: actions.begin()
        case .running, .held: actions.toggleHold()
        case .onBreak: actions.checkIn()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusText)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("popover-status")

            if let timeText {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(timeText)
                        .font(.system(size: 30, weight: .light, design: .monospaced))
                        .accessibilityIdentifier("popover-time")
                    CompanionFieldView(state: snapshot.phase == .held ? "held" : "breathing", motionStilled: reduceMotion)
                        .frame(width: 28, height: 28)
                }
                if !snapshot.taskLine.isEmpty {
                    Text(snapshot.taskLine)
                        .font(.callout)
                        .lineLimit(2)
                        .accessibilityIdentifier("popover-task")
                }
            }

            Divider()

            Button(primaryControlLabel) { primaryAction() }
                .accessibilityIdentifier("popover-primary")

            if snapshot.hasSession {
                Button("Check in") { actions.checkIn() }
                    .accessibilityIdentifier("popover-check-in")
            }

            Button("Open Praxmodoro") { actions.openMainWindow() }
                .accessibilityIdentifier("popover-open-main")
        }
        .buttonStyle(.borderless)
        .padding(14)
        .frame(width: 240, alignment: .leading)
        .foregroundStyle(SurfacePalette.primaryText(increasedContrast: contrast == .increased))
        .background(SurfacePalette.background(reduceTransparency: reduceTransparency))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
