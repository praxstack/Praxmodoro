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
            // Strip comment text first (quotes inside comments break pairing),
            // then match per line (no multiline literals in these sources).
            let literals = source.split(separator: "\n", omittingEmptySubsequences: false).flatMap { line -> [String] in
                var code = String(line)
                if let commentStart = code.range(of: "//"),
                   !code[..<commentStart.lowerBound].contains("\"") {
                    code = String(code[..<commentStart.lowerBound])
                }
                return code.matches(of: /"((?:[^"\\]|\\.)*)"/).map { String($0.1).lowercased() }
            }
            // Copy that explicitly promises the ABSENCE of a mechanic is
            // compliant ("never a streak"); strip negations before linting.
            let negations = ["never a score, never a streak", "never a streak", "no streaks", "no scores"]
            for var literal in literals {
                // Identifier-shaped literals (no whitespace) are not copy —
                // e.g. "about-provenance" false-matching "proven".
                guard literal.contains(" ") else { continue }
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
