import Foundation
import Testing

@Suite struct OneProductContractTests {
    @Test func testProductionHasNoEditionAPI() throws {
        let appRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = appRoot.appendingPathComponent("Sources")
        let enumerator = try #require(
            FileManager.default.enumerator(at: sourcesRoot, includingPropertiesForKeys: nil))
        let swiftFiles = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(!swiftFiles.isEmpty, "production source scan must not be empty")

        let generator = appRoot.deletingLastPathComponent().appendingPathComponent("scripts/generate.sh")
        #expect(FileManager.default.fileExists(atPath: generator.path), "generator must be scanned")

        let vocabulary = try NSRegularExpression(
            pattern: #"\b(?:edition|lite|pro|enterprise|tier|license|paywall|paywalled|upsell)\b"#,
            options: [.caseInsensitive])
        let identifierPatterns = ["defaultGrants", "grants", "Edition:", "[Edition:"]

        for file in swiftFiles + [generator] {
            let source = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            #expect(
                vocabulary.firstMatch(in: source, range: range) == nil,
                "\(file.path) contains retired product vocabulary")
            for pattern in identifierPatterns {
                #expect(!source.contains(pattern), "\(file.path) contains retired identifier \(pattern)")
            }
        }
    }
}
