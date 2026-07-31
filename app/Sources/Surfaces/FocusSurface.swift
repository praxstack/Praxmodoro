import SwiftUI
import PraxmodoroCore

/// The timer holds the task; the field is ambient presence. No element here
/// scores the user (spec: focus-loop-ui "Nothing scores the user").
struct FocusSurface: View {
    /// Control catalog — tests pin the absence of scoring elements.
    static let controls = [
        "task-line", "next-action-line", "companion-field", "time-remaining",
        "hold-toggle", "thought-parking-input", "parked-thoughts-list",
    ]

    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thoughtDraft = ""

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Now focusing").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text(model.taskTitle).font(.title2.weight(.semibold))
                        .accessibilityIdentifier("task-line")
                    if !model.firstAction.isEmpty {
                        Text("Next: \(model.firstAction)").foregroundStyle(.secondary)
                            .accessibilityIdentifier("next-action-line")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    CompanionFieldView(state: model.isHeld ? "held" : "breathing", motionStilled: reduceMotion)
                        .frame(width: 260, height: 260)
                        .accessibilityIdentifier("companion-field")
                        .accessibilityElement()
                        .accessibilityLabel(model.fieldAccessibilitySummary(at: Date()))
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        Text(timeText(at: context.date))
                            .font(.system(size: 44, weight: .light, design: .monospaced))
                            .accessibilityIdentifier("time-remaining")
                    }
                }

                Button {
                    try? model.toggleHold()
                } label: {
                    Image(systemName: model.isHeld ? "play.fill" : "pause.fill")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .keyboardShortcut(.space, modifiers: [])
                .accessibilityLabel(model.isHeld ? "Resume timer" : "Hold timer")
                .accessibilityIdentifier("hold-toggle")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Thought parking").font(.headline)
                Text("Capture without changing context.").font(.caption).foregroundStyle(.secondary)
                ForEach(model.parkedThoughts, id: \.self) { thought in
                    Text(thought).font(.callout)
                }
                .accessibilityIdentifier("parked-thoughts-list")
                TextField("Park a thought…", text: $thoughtDraft)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("thought-parking-input")
                    .onSubmit {
                        try? model.parkThought(thoughtDraft)
                        thoughtDraft = ""
                    }
            }
            .frame(width: 240)
        }
        .padding(32)
    }

    private func timeText(at now: Date) -> String {
        guard let remaining = model.remaining(at: now) else { return "open" }
        let total = Int(remaining.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
