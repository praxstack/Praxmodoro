import SwiftUI

/// Build provenance shown in About (spec: app-scaffold "Deterministic
/// versioning and provenance"). Values are stamped by scripts/generate.sh
/// into Generated/BuildProvenance.swift.
struct Provenance {
    let version: String
    let gitSHA: String

    static let current = Provenance(
        version: BuildProvenance.version,
        gitSHA: BuildProvenance.gitSHA
    )

    var aboutText: String {
        "Praxmodoro \(version) (\(gitSHA)) · local-first, no account"
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Praxmodoro").font(.title2.weight(.bold))
            Text(Provenance.current.aboutText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("about-provenance")
            Text("An ADHD-aware focus companion. Your data stays on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 360)
    }
}
