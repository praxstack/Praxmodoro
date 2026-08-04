import SwiftUI

/// The clock face, extracted so that no surface formats time itself.
///
/// `FocusSurface` legitimately reads the wall clock — it is the one place that
/// asks the model for a fresh snapshot per tick — but it has no business
/// turning an interval into text. Handing that job to a pure surface means the
/// focus surface holds no formatting logic to corrupt, and the readout is
/// covered by the same drift test as every other companion surface (spec:
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
