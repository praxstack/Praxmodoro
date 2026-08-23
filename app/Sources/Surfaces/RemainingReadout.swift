import SwiftUI

/// The clock face, extracted so that no surface formats time itself.
///
/// The scene root asks the model for one snapshot per render and hands its
/// immutable display here. The readout holds no clock or formatting logic and
/// is covered by the same drift test as every other companion surface (spec:
/// companion-surfaces "No surface counts time").
struct RemainingReadout: View {
    let display: CompanionDisplay

    /// "open" is the honest rendering for an open-ended policy that is
    /// running; there is no clock to show, but there is a session.
    var text: String { display.timeText ?? "open" }

    var body: some View {
        Text(text)
            .font(.system(size: 44, weight: .light, design: .monospaced))
            .accessibilityIdentifier("time-remaining")
    }
}
