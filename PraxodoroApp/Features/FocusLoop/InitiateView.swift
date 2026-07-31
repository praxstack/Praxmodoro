import SwiftUI

struct InitiateView: View {
  var body: some View {
    VStack(spacing: 12) {
      Text("Praxodoro")
        .font(.system(size: 36, weight: .semibold, design: .rounded))
        .accessibilityIdentifier("initiate.heading")
        .accessibilityAddTraits(.isHeader)

      Text("One clear next move.")
        .font(.title3)
        .foregroundStyle(.secondary)
    }
    .frame(minWidth: 480, minHeight: 360)
    .padding(32)
  }
}
