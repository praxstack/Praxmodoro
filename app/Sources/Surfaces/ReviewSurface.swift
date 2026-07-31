import SwiftUI

/// Today, written down gently. The timeline records what happened; insights
/// stay descriptive and uncertainty-aware (spec: focus-loop-ui "Review is a
/// record, not a verdict").
struct ReviewSurface: View {
    static let controls = ["timeline", "insight-card", "companion-field", "new-session-control"]

    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today, written down gently.")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                if let entries = try? model.reviewTimeline() {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(entry.at.formatted(date: .omitted, time: .shortened))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(entry.label)
                            }
                        }
                    }
                    .accessibilityIdentifier("timeline")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                CompanionFieldView(state: "settled", motionStilled: reduceMotion)
                    .frame(width: 110, height: 110)
                    .accessibilityIdentifier("companion-field")
                Text("Observed, not concluded").font(.caption.smallCaps()).foregroundStyle(.secondary)
                Text(model.reviewInsight)
                    .font(.callout)
                    .accessibilityIdentifier("insight-card")
                Button {
                    model.surface = .initiate
                } label: {
                    Label("Begin something new", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("new-session-control")
            }
            .frame(width: 250)
        }
        .padding(32)
    }
}
