import Foundation
import Testing
@testable import Praxmodoro

/// Spec: app-scaffold "Deterministic versioning and provenance".
@Suite struct ProvenanceTests {
    @Test func testAboutShowsProvenance() {
        let provenance = Provenance.current
        #expect(!provenance.version.isEmpty)
        #expect(!provenance.gitSHA.isEmpty)
        #expect(provenance.gitSHA != "unknown", "generate.sh must stamp the git SHA")
        #expect(provenance.edition == "lite")

        let text = provenance.aboutText
        #expect(text.contains(provenance.version))
        #expect(text.contains(provenance.gitSHA))
        #expect(text.lowercased().contains("lite"))
    }
}
