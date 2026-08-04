import SwiftUI

/// A small always-on-top readout of the running session: the task, the time,
/// and hold/resume. Like every companion surface it is a pure function of a
/// CompanionDisplay — it has no clock and no model, so it cannot drift away from the
/// engine (spec: companion-surfaces "Floating focus capsule stays above other
/// windows").
struct FocusCapsule: View {
    static let controls = ["capsule-task", "capsule-time", "capsule-hold"]

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

    /// Exposed so the Reduce Motion standdown is assertable at runtime.
    func companionField(motionStilled: Bool) -> CompanionFieldView {
        CompanionFieldView(state: display.phase == .held ? "held" : "breathing", motionStilled: motionStilled)
    }

    var body: some View {
        HStack(spacing: 12) {
            companionField(motionStilled: reduceMotion)
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

            Button {
                actions.toggleHold()
            } label: {
                Image(systemName: display.phase == .held ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(display.phase == .held ? "Resume timer" : "Hold timer")
            .accessibilityIdentifier("capsule-hold")
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
