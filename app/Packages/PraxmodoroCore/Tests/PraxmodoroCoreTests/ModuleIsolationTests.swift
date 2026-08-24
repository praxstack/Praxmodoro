import Foundation
import Testing

/// Spec: timer-engine "Engine is UI-free and capability-registry-independent".
/// The engine may import only Foundation — no SwiftUI, AppKit, network,
/// persistence, or app-layer capability-registry awareness. Enforced
/// structurally by scanning the module sources.
@Suite struct ModuleIsolationTests {
    @Test func testCoreLinksOnlyFoundation() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ModuleIsolationTests.swift
            .deletingLastPathComponent()  // PraxmodoroCoreTests
            .deletingLastPathComponent()  // Tests
            .appendingPathComponent("Sources/PraxmodoroCore")
        let files = try FileManager.default.contentsOfDirectory(at: sourcesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)

        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            let imports = source.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("import ") }
                .map { $0.replacingOccurrences(of: "import ", with: "") }
            for module in imports {
                #expect(module == "Foundation", "\(file.lastPathComponent) imports \(module)")
            }
        }
    }
}
