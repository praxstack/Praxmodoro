import PraxmodoroCore
import SwiftUI

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

    /// Everything this surface renders comes from one snapshot instant.
    private var snapshot: SessionSnapshot { model.snapshot(at: Date()) }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Now focusing").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text(snapshot.taskLine).font(.title2.weight(.semibold))
                        .accessibilityIdentifier("task-line")
                    if !snapshot.nextAction.isEmpty {
                        Text("Next: \(snapshot.nextAction)").foregroundStyle(.secondary)
                            .accessibilityIdentifier("next-action-line")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    CompanionFieldView(
                        state: snapshot.phase == .held ? "held" : "breathing", motionStilled: reduceMotion,
                        pulseSignal: model.fieldPulse
                    )
                    .frame(width: 260, height: 260)
                    .accessibilityIdentifier("companion-field")
                    .accessibilityElement()
                    .accessibilityLabel(snapshot.accessibilitySummary)
                    // The timeline re-asks the model; it never advances a count
                    // of its own (spec: companion-surfaces "No surface counts
                    // time"). Each tick is a fresh snapshot at that instant.
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        Text(model.snapshot(at: context.date).remainingText ?? "open")
                            .font(.system(size: 44, weight: .light, design: .monospaced))
                            .accessibilityIdentifier("time-remaining")
                    }
                }

                Button {
                    try? model.toggleHold()
                } label: {
                    Image(systemName: snapshot.phase == .held ? "play.fill" : "pause.fill")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .keyboardShortcut(.space, modifiers: [])
                .accessibilityLabel(snapshot.phase == .held ? "Resume timer" : "Hold timer")
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
}
