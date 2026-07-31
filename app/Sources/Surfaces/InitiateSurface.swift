import SwiftUI
import PraxmodoroCore

/// One task, one tiny first action, capacity, policy, begin — and nothing
/// else on the start path (spec: focus-loop-ui "One-task initiation").
/// `startPathControls` is the surface's contract; tests pin it.
struct InitiateSurface: View {
    /// The complete start path. Rendering follows this catalog exactly.
    static let startPathControls = [
        "task-input", "first-action", "capacity-choice", "policy-choice", "begin-control",
    ]

    @Bindable var model: AppModel
    @State private var beginFailed = false

    private let capacities = ["foggy", "steady", "restless", "charged"]
    private let policies: [TimingPolicy] = [.gentleStart, .classic, .flow, .recoveryFirst]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("One small step, held with you.")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                Text("Choose one task").font(.headline)
                TextField("What has your attention?", text: $model.taskTitle)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("task-input")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("The first visible action").font(.headline)
                TextField("Concrete, reversible, about two minutes", text: $model.firstAction)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("first-action")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Capacity right now").font(.headline)
                Picker("Capacity", selection: $model.capacity) {
                    ForEach(capacities, id: \.self) { Text($0.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("capacity-choice")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Session policy").font(.headline)
                Picker("Policy", selection: $model.policy) {
                    ForEach(policies, id: \.name) { policy in
                        Text(policyLabel(policy)).tag(policy)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("policy-choice")
            }

            Button {
                do { try model.begin() } catch { beginFailed = true }
            } label: {
                Label("Begin", systemImage: "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("begin-control")
            .disabled(model.taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)

            if beginFailed {
                Text("The session couldn't start. Nothing was lost — try Begin again.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: 560)
    }

    private func policyLabel(_ policy: TimingPolicy) -> String {
        switch policy.name {
        case "gentle-start": "Gentle start"
        case "classic": "Classic 25+5"
        case "flow": "Flow"
        default: "Recovery first"
        }
    }
}

extension TimingPolicy: @retroactive Identifiable {
    public var id: String { name }
}
