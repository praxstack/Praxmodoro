import Foundation
import Testing
@testable import PraxmodoroStore

@Suite struct StoreRecoveryTests {
    @Test func testCorruptStoreStillReachesInitiate() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("praxmodoro.store")
        try Data("this is not a database".utf8).write(to: url)

        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let (store, notice) = try LocalStore.open(at: url, now: now)

        // The app still reaches a working store (initiate surface can render)…
        let sessionID = UUID()
        try store.createSession(id: sessionID, policyName: "classic", startedAt: now)
        #expect(try store.events(sessionID: sessionID).isEmpty)

        // …the unreadable store is preserved under a recovery name…
        let recovered = try #require(notice)
        #expect(FileManager.default.fileExists(atPath: recovered.recoveredTo.path))
        #expect(String(data: try Data(contentsOf: recovered.recoveredTo), encoding: .utf8) == "this is not a database")

        // …and the notice says what happened, plainly and without blame.
        #expect(recovered.message.contains(recovered.recoveredTo.lastPathComponent))
    }

    @Test func testHealthyStoreOpensWithoutNotice() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("praxmodoro.store")

        let (_, firstNotice) = try LocalStore.open(at: url, now: .now)
        #expect(firstNotice == nil)
        let (_, secondNotice) = try LocalStore.open(at: url, now: .now)
        #expect(secondNotice == nil)
    }
}
