import Foundation
import Testing

/// Spec: focus-loop-ui "Non-medical language everywhere" — enforced
/// structurally: every string literal in the app sources is linted against
/// the banned-claims lexicon. (Strings-catalog extraction is deferred to the
/// localization pass; this scan covers all user-facing copy today.)
@Suite struct CopyToneTests {
    @Test func testNoMedicalOrJudgmentClaims() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PraxmodoroTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil))
        let banned = [
            "treat", "cure", "diagnos", "therapy", "therapeutic", "clinically",
            "proven", "optimal schedule", "optimal cadence", "streak",
            "lazy", "procrastinat", "guilt", "shame", "discipline yourself",
        ]
        var scanned = 0
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            scanned += 1
            let source = try String(contentsOf: file, encoding: .utf8)
            // Only string literals — identifiers/comments may use these words.
            let literals = source.matches(of: /"((?:[^"\\]|\\.)*)"/).map { String($0.1).lowercased() }
            // Copy that explicitly promises the ABSENCE of a mechanic is
            // compliant ("never a streak"); strip negations before linting.
            let negations = ["never a score, never a streak", "never a streak", "no streaks", "no scores"]
            for var literal in literals {
                for negation in negations {
                    literal = literal.replacingOccurrences(of: negation, with: "")
                }
                for term in banned {
                    #expect(!literal.contains(term), "\(file.lastPathComponent): banned term “\(term)” in copy: “\(literal.prefix(60))…”")
                }
            }
        }
        #expect(scanned > 5, "source scan must actually cover the app sources")
    }
}
