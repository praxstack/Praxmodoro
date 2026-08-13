import SwiftUI

/// Rest that keeps your place. Suggestions come from what you told the
/// companion — never from a claim about what is optimal (spec: focus-loop-ui).
struct BreakSurface: View {
    static let controls = [
        "companion-field", "break-suggestion", "break-choices", "why-disclosure", "reentry-card",
        "ready-control", "checkin-response",
    ]

    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var whyExpanded = false

    private let choices = ["Water", "Stretch", "Step away", "Quiet"]

    /// The response to the answer that brought us here (GitHub #3).
    var checkinResponseText: String? { model.lastCheckinResponse }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(spacing: 20) {
                Text("Rest that keeps your place.")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let response = checkinResponseText {
                    Text(response)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("checkin-response")
                        .accessibilityAddTraits(.updatesFrequently)
                }

                CompanionFieldView(
                    state: "expanded", motionStilled: model.fieldIsStilled(systemReduceMotion: reduceMotion),
                    pulseSignal: model.fieldPulse
                )
                .frame(width: 220, height: 220)
                .accessibilityIdentifier("companion-field")

                Text(model.breakSuggestion)
                    .font(.title3)
                    .accessibilityIdentifier("break-suggestion")

                // The cadence's longer break, offered in words when due —
                // a suggestion with ordinary decline, never a score
                // (spec: "Long-break cadence suggests, never scores").
                if let minutes = model.longBreakMinutesDueNow {
                    Text("This one could be longer — \(minutes) minutes, if you want it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("long-break-suggestion")
                }

                HStack(spacing: 10) {
                    ForEach(choices, id: \.self) { choice in
                        Button(choice) { try? model.chooseBreak(choice.lowercased()) }
                            .buttonStyle(.bordered)
                    }
                }
                .accessibilityIdentifier("break-choices")

                DisclosureGroup("Why this suggestion?", isExpanded: $whyExpanded) {
                    Text(model.breakSuggestionProvenance)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("why-disclosure")
                .frame(maxWidth: 380)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Re-entry card").font(.caption.smallCaps()).foregroundStyle(.secondary)
                Text("The way back is already set.").font(.headline)
                if !model.reentryStep.isEmpty {
                    Text(model.reentryStep)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
                        .accessibilityIdentifier("reentry-card")
                }
                Button {
                    try? model.endBreak()
                } label: {
                    Label("Ready when you are", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: [])
                .accessibilityIdentifier("ready-control")
                Text("The break can end whenever you say — completion is not the point.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 260)
        }
        .padding(32)
    }
}
