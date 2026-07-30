import Foundation
import Testing
@testable import PraxmodoroStore

/// Spec: session-persistence "No network, no account" and "Data minimization".
/// Both guarantees are structural: enforced by scanning the module's sources
/// and schema, not by policy documents.
@Suite struct StoreAuditTests {
    private var sourceFiles: [URL] {
        get throws {
            let dir = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/PraxmodoroStore")
            return try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "swift" }
        }
    }

    @Test func testNoNetworkSymbolsLinked() throws {
        let banned = ["import Network", "import CloudKit", "URLSession", "URLRequest", "NWConnection"]
        for file in try sourceFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for symbol in banned {
                #expect(!source.contains(symbol), "\(file.lastPathComponent) contains banned symbol \(symbol)")
            }
        }
    }

    @Test func testNoPassiveObservationFields() throws {
        // The schema may store only what the user entered or chose plus engine
        // transitions. Any field smelling of foreign-app observation fails.
        let banned = ["appName", "bundleIdentifier", "windowTitle", "url", "screenContent", "keystrokes", "heartRate"]
        let attributes = LocalStore.schema.entities.flatMap { entity in
            entity.attributes.map(\.name)
        }
        #expect(!attributes.isEmpty)
        for name in attributes {
            #expect(!banned.contains(name), "schema field \(name) suggests passive observation")
        }
    }
}
