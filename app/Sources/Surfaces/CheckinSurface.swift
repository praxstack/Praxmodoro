import SwiftUI

/// A question, not a report card. Four honest answers, no failure state
/// (spec: focus-loop-ui). The timer is held while this surface is open.
struct CheckinSurface: View {
    static let controls = ["checkin-question", "checkin-options", "companion-field", "return-note"]

    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Check-in · timer held").font(.caption.smallCaps()).foregroundStyle(.secondary)
                    Text("How does the step fit right now?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("checkin-question")
                }
                Spacer()
                CompanionFieldView(state: "ripple", motionStilled: model.fieldIsStilled(systemReduceMotion: reduceMotion))
                    .frame(width: 96, height: 96)
                    .accessibilityIdentifier("companion-field")
            }

            Text("Pick the closest one. Your answer adjusts the next step or the break — never a score, never a streak.")
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(Array(CheckinAnswer.allCases.enumerated()), id: \.element) { index, answer in
                    Button {
                        try? model.answer(answer)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.monospaced())
                                .frame(width: 22, height: 22)
                                .background(Circle().strokeBorder(.secondary.opacity(0.4)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(answer.label).font(.body.weight(.semibold))
                                Text(answer.detail).font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                }
            }
            .accessibilityIdentifier("checkin-options")

            Text("No answer here is wrong.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("return-note")
        }
        .padding(32)
        .frame(maxWidth: 640)
    }
}
