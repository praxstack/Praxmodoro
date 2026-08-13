import SwiftUI

/// What a companion surface may ask for. Closures keep these surfaces pure:
/// they render a `CompanionDisplay` and report intent, and never reach for the
/// model (spec: companion-surfaces "No surface counts time").
@MainActor
struct CompanionActions {
    var begin: () -> Void = {}
    var toggleHold: () -> Void = {}
    var checkIn: () -> Void = {}
    /// Distinct from `toggleHold`: the engine has no hold transition out of a
    /// break, so a break-phase control that routed through hold silently threw
    /// and did nothing (found in review).
    var endBreak: () -> Void = {}
    var openMainWindow: () -> Void = {}
    /// ±1 minute, decided by the model — surfaces never touch an interval
    /// (spec: "Rewind and forward as recorded adjustments").
    var forwardMinute: () -> Void = {}
    var rewindMinute: () -> Void = {}

    /// For tests and previews: renders the surface without wiring anything.
    static let inert = CompanionActions()
}

/// The loop, reachable from the menu bar without fronting the app.
struct MenuBarPopover: View {
    let display: CompanionDisplay
    let actions: CompanionActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var statusText: String { display.statusLine }

    /// nil when there is no session — the popover then renders no clock at
    /// all rather than a zero (spec: "Popover with no session").
    var timeText: String? { display.timeText }

    var primaryControlLabel: String {
        switch display.phase {
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
        guard display.hasSession else {
            return ["popover-status", "popover-primary", "popover-open-main"]
        }
        var catalog = ["popover-status", "popover-time", "popover-task", "popover-primary", "popover-check-in", "popover-open-main"]
        if display.offersAdjustment { catalog.insert("popover-adjust", at: 3) }
        return catalog
    }

    /// Internal rather than private so a test can prove the break-phase
    /// control actually does something.
    func primaryAction() {
        switch display.phase {
        case .idle, .closed: actions.begin()
        case .running, .held: actions.toggleHold()
        case .onBreak: actions.endBreak()
        }
    }

    /// The acknowledgement signal, passed as a value at construction like
    /// everything else these surfaces receive (spec: focus-loop-ui "Choice
    /// acknowledgement").
    var pulseSignal: Int = 0

    /// Forces the motion standdown regardless of the environment.
    ///
    /// `accessibilityReduceMotion` is read-only in the macOS 26 SDK, so an
    /// offscreen render cannot be made deterministic from the outside, and the
    /// in-app "Motion: still" preference has to reach these surfaces somehow.
    /// Production sets it from `AppModel.motionStilled`; nil falls through to
    /// the environment, which keeps system Reduce Motion authoritative.
    var motionStilledOverride: Bool?

    private var motionStilled: Bool { motionStilledOverride ?? reduceMotion }

    /// The field this surface shows, exposed so the Reduce Motion standdown
    /// is assertable at runtime rather than inferred from source (spec:
    /// companion-surfaces "Reduce Motion standdown on the new surfaces").
    func companionField(motionStilled: Bool) -> CompanionFieldView {
        CompanionFieldView(state: display.phase == .held ? "held" : "breathing", motionStilled: motionStilled, pulseSignal: pulseSignal)
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
                    companionField(motionStilled: motionStilled)
                        .frame(width: 28, height: 28)
                }
                if !display.taskLine.isEmpty {
                    Text(display.taskLine)
                        .font(.callout)
                        .lineLimit(2)
                        .accessibilityIdentifier("popover-task")
                }
            }

            Divider()

            // The minute nudges, wherever the loop is operated from —
            // present only while a finite block runs (spec: "Nudges never
            // rescue an expired block").
            if display.offersAdjustment {
                HStack(spacing: 8) {
                    Button("−1 min") { actions.rewindMinute() }
                    Button("+1 min") { actions.forwardMinute() }
                }
                .accessibilityIdentifier("popover-adjust")
            }
            Button(primaryControlLabel) { primaryAction() }
                .accessibilityIdentifier("popover-primary")

            if display.hasSession {
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
