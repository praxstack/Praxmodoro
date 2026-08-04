import Foundation
import SwiftData

/// Event vocabulary for the append-only session log (spec: session-persistence).
public enum StoredEventKind: String, Codable, Sendable, Equatable {
    case transition
    case checkinAnswer
    case thoughtParked
    case breakChoice
    case capacityReport
    case edit
    case clockAnomaly
}

/// A plain value view of a stored event, for consumers outside SwiftData.
public struct StoredEvent: Equatable, Sendable {
    public let id: UUID
    public let kind: StoredEventKind
    public let payload: String
    public let at: Date
    public let references: UUID?
}

@Model final class SessionRecordModel {
    @Attribute(.unique) var id: UUID
    var policyName: String
    var startedAt: Date
    init(id: UUID, policyName: String, startedAt: Date) {
        self.id = id
        self.policyName = policyName
        self.startedAt = startedAt
    }
}

@Model final class SessionEventModel {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var kindRaw: String
    var payload: String
    var at: Date
    var orderIndex: Int
    var references: UUID?
    init(id: UUID, sessionID: UUID, kindRaw: String, payload: String, at: Date, orderIndex: Int, references: UUID?) {
        self.id = id
        self.sessionID = sessionID
        self.kindRaw = kindRaw
        self.payload = payload
        self.at = at
        self.orderIndex = orderIndex
        self.references = references
    }
}

@Model final class TaskRecordModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var firstAction: String
    var createdAt: Date
    init(id: UUID, title: String, firstAction: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.firstAction = firstAction
        self.createdAt = createdAt
    }
}

@Model final class CapacityReportModel {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var value: String
    var at: Date
    init(id: UUID, sessionID: UUID, value: String, at: Date) {
        self.id = id
        self.sessionID = sessionID
        self.value = value
        self.at = at
    }
}

public enum StoreError: Error, Equatable {
    case unknownSession(UUID)
}

/// Plain-language record of a store recovery (spec: "Store corruption
/// degrades gracefully"). Informational, never blaming.
public struct RecoveryNotice: Equatable, Sendable {
    public let recoveredTo: URL
    public let message: String
}

/// Local-first store. Everything stays in the on-device container; this module
/// has no networking imports by construction (spec: no network, no account).
/// Named SessionRecordModel etc. to avoid shadowing PraxmodoroCore.Session.
public final class LocalStore {
    private let container: ModelContainer
    private let context: ModelContext

    public static var schema: Schema {
        Schema([SessionRecordModel.self, SessionEventModel.self, TaskRecordModel.self, CapacityReportModel.self])
    }

    /// The schema this store's *live* container actually resolved.
    ///
    /// The M1 parity test compared the static declaration above to itself,
    /// which could not fail. Exposing the container's own schema lets a test
    /// compare two real configurations — in-memory against on-disk — which
    /// can (spec: session-persistence "Two-configuration parity against live
    /// containers").
    public var containerSchema: Schema { container.schema }

    public init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: Self.schema, configurations: [config])
        self.context = ModelContext(container)
    }

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    public init(url: URL) throws {
        let config = ModelConfiguration(url: url)
        self.container = try ModelContainer(for: Self.schema, configurations: [config])
        self.context = ModelContext(container)
    }

    /// Open the store at `url`. If it cannot be opened or migrated, the
    /// unreadable file is preserved under a recovery name, a fresh store is
    /// created, and the returned notice says plainly what happened.
    public static func open(at url: URL, now: Date) throws -> (LocalStore, RecoveryNotice?) {
        do {
            return (try LocalStore(url: url), nil)
        } catch {
            let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "-")
            let recovery = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent).recovery-\(stamp)")
            let fm = FileManager.default
            try fm.moveItem(at: url, to: recovery)
            for suffix in ["-wal", "-shm"] {
                let sidecar = URL(fileURLWithPath: url.path + suffix)
                if fm.fileExists(atPath: sidecar.path) {
                    try? fm.moveItem(at: sidecar, to: URL(fileURLWithPath: recovery.path + suffix))
                }
            }
            let fresh = try LocalStore(url: url)
            let notice = RecoveryNotice(
                recoveredTo: recovery,
                message:
                    "Your session records could not be read, so Praxmodoro started a fresh local store. Nothing was deleted — the previous file is preserved as \(recovery.lastPathComponent) in the same folder."
            )
            return (fresh, notice)
        }
    }

    public func createSession(id: UUID, policyName: String, startedAt: Date) throws {
        context.insert(SessionRecordModel(id: id, policyName: policyName, startedAt: startedAt))
        try context.save()
    }

    @discardableResult
    public func appendEvent(sessionID: UUID, kind: StoredEventKind, payload: String, at: Date, references: UUID? = nil) throws -> UUID {
        let next = try events(sessionID: sessionID).count
        let id = UUID()
        context.insert(
            SessionEventModel(
                id: id, sessionID: sessionID, kindRaw: kind.rawValue, payload: payload, at: at, orderIndex: next, references: references))
        try context.save()
        return id
    }

    /// Corrections never mutate: an edit is a new event referencing the
    /// original (spec: "Event log is append-only" / "No silent rewrites").
    public func editEvent(sessionID: UUID, originalID: UUID, newPayload: String, at: Date) throws {
        try appendEvent(sessionID: sessionID, kind: .edit, payload: newPayload, at: at, references: originalID)
    }

    public struct SessionSummary: Equatable, Sendable {
        public let id: UUID
        public let policyName: String
        public let startedAt: Date
    }

    /// Most recently started session, if any (relaunch restore).
    public func latestSession() throws -> SessionSummary? {
        var descriptor = FetchDescriptor<SessionRecordModel>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map {
            SessionSummary(id: $0.id, policyName: $0.policyName, startedAt: $0.startedAt)
        }
    }

    /// The session's one task (M1: 1:1, task id == session id).
    public func saveTask(sessionID: UUID, title: String, firstAction: String, at: Date) throws {
        context.insert(TaskRecordModel(id: sessionID, title: title, firstAction: firstAction, createdAt: at))
        try context.save()
    }

    public func task(sessionID: UUID) throws -> (title: String, firstAction: String)? {
        let descriptor = FetchDescriptor<TaskRecordModel>(predicate: #Predicate { $0.id == sessionID })
        return try context.fetch(descriptor).first.map { ($0.title, $0.firstAction) }
    }

    public func events(sessionID: UUID) throws -> [StoredEvent] {
        let descriptor = FetchDescriptor<SessionEventModel>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try context.fetch(descriptor).map {
            StoredEvent(
                id: $0.id, kind: StoredEventKind(rawValue: $0.kindRaw) ?? .transition, payload: $0.payload, at: $0.at,
                references: $0.references)
        }
    }
}
