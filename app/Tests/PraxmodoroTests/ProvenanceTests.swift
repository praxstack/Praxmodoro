import Foundation
import Testing
@testable import Praxmodoro

/// Spec: app-scaffold "Deterministic build provenance".
@Suite struct ProvenanceTests {
    @Test func testAboutShowsProvenance() {
        let provenance = Provenance.current
        #expect(!provenance.version.isEmpty)
        #expect(!provenance.gitSHA.isEmpty)
        #expect(provenance.gitSHA != "unknown", "generate.sh must stamp the git SHA")

        let text = provenance.aboutText
        #expect(text.contains(provenance.version))
        #expect(text.contains(provenance.gitSHA))
        #expect(text.contains("local-first, no account"))
        for term in ["edition", "lite", "pro", "enterprise", "tier", "license", "paywall", "upsell"] {
            #expect(!text.lowercased().contains(term), "About provenance contains product-tier term: \(term)")
        }
    }
}
