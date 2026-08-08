import SwiftUI

/// A small always-on-top readout of the running session: the task, the time,
/// and hold/resume. Like every companion surface it is a pure function of a
/// CompanionDisplay — it has no clock and no model, so it cannot drift away from the
/// engine (spec: companion-surfaces "Floating focus capsule stays above other
/// windows").
struct FocusCapsule: View {
    /// The engine has no hold transition out of a break, so during one the
    /// capsule shows no hold control rather than a dead one (found in review).
    var offersHold: Bool { display.phase != .onBreak }

    var controls: [String] {
        offersHold ? ["capsule-task", "capsule-time", "capsule-hold"] : ["capsule-task", "capsule-time"]
    }

    let display: CompanionDisplay
    let actions: CompanionActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var timeText: String? { display.timeText }
    var taskText: String { display.taskLine }

    var accessibilityLabel: String {
        guard let timeText else { return "Focus capsule: \(display.statusLine)" }
        return "Focus capsule: \(display.taskLine), \(timeText) left, \(display.statusLine)"
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

    /// Exposed so the Reduce Motion standdown is assertable at runtime.
    func companionField(motionStilled: Bool) -> CompanionFieldView {
        CompanionFieldView(state: display.phase == .held ? "held" : "breathing", motionStilled: motionStilled, pulseSignal: pulseSignal)
    }

    var body: some View {
        HStack(spacing: 12) {
            companionField(motionStilled: motionStilled)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(taskText.isEmpty ? display.statusLine : taskText)
                    .font(.caption)
                    .lineLimit(1)
                    .accessibilityIdentifier("capsule-task")
                Text(timeText ?? display.statusLine)
                    .font(.system(size: 19, weight: .light, design: .monospaced))
                    .accessibilityIdentifier("capsule-time")
            }

            if offersHold {
                Button {
                    actions.toggleHold()
                } label: {
                    Image(systemName: display.phase == .held ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(display.phase == .held ? "Resume timer" : "Hold timer")
                .accessibilityIdentifier("capsule-hold")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(SurfacePalette.background(reduceTransparency: reduceTransparency))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
