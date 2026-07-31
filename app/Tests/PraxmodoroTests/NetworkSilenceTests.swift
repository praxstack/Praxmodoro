import Foundation
import Testing
@testable import Praxmodoro
import PraxmodoroStore

/// Spec: app-scaffold "No hidden cloud dependency" — zero outbound
/// connections across a full loop, enforced two ways: a URLProtocol canary
/// during a real loop run, and a whole-app source scan for network symbols.
final class NetworkCanary: URLProtocol {
    nonisolated(unsafe) static var observed: [String] = []
    override class func canInit(with request: URLRequest) -> Bool {
        observed.append(request.url?.absoluteString ?? "unknown")
        return false
    }
}

@MainActor
@Suite struct NetworkSilenceTests {
    @Test func testFullLoopMakesZeroOutboundConnections() throws {
        URLProtocol.registerClass(NetworkCanary.self)
        defer { URLProtocol.unregisterClass(NetworkCanary.self) }
        NetworkCanary.observed = []

        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let model = AppModel(store: try LocalStore(inMemory: true), clock: { now })
        model.taskTitle = "Edit the outline"
        try model.begin()
        try model.parkThought("A thought")
        now = now.addingTimeInterval(600)
        try model.openCheckin()
        try model.answer(.needBreak)
        try model.chooseBreak("stretch")
        now = now.addingTimeInterval(120)
        try model.endBreak()
        now = now.addingTimeInterval(1200)
        try model.closeSession()
        _ = try model.reviewTimeline()

        #expect(NetworkCanary.observed.isEmpty, "outbound requests observed: \(NetworkCanary.observed)")
    }

    @Test func testNoNetworkSymbolsInAppSources() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
        let enumerator = try #require(FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil))
        let banned = ["URLSession", "import Network", "import CloudKit", "NWConnection", "URLRequest"]
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for symbol in banned {
                #expect(!source.contains(symbol), "\(file.lastPathComponent) contains \(symbol)")
            }
        }
    }
}
