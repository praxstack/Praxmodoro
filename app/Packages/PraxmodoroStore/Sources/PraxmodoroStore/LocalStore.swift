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

/// Local-first store. Everything stays in the on-device container; this module
/// has no networking imports by construction (spec: no network, no account).
/// Named SessionRecordModel etc. to avoid shadowing PraxmodoroCore.Session.
public final class LocalStore {
    private let container: ModelContainer
    private let context: ModelContext

    static var schema: Schema {
        Schema([SessionRecordModel.self, SessionEventModel.self, TaskRecordModel.self, CapacityReportModel.self])
    }

    public init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: Self.schema, configurations: [config])
        self.context = ModelContext(container)
    }

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    public func createSession(id: UUID, policyName: String, startedAt: Date) throws {
        context.insert(SessionRecordModel(id: id, policyName: policyName, startedAt: startedAt))
        try context.save()
    }

    @discardableResult
    public func appendEvent(sessionID: UUID, kind: StoredEventKind, payload: String, at: Date, references: UUID? = nil) throws -> UUID {
        let next = try events(sessionID: sessionID).count
        let id = UUID()
        context.insert(SessionEventModel(id: id, sessionID: sessionID, kindRaw: kind.rawValue, payload: payload, at: at, orderIndex: next, references: references))
        try context.save()
        return id
    }

    public func events(sessionID: UUID) throws -> [StoredEvent] {
        let descriptor = FetchDescriptor<SessionEventModel>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try context.fetch(descriptor).map {
            StoredEvent(id: $0.id, kind: StoredEventKind(rawValue: $0.kindRaw) ?? .transition, payload: $0.payload, at: $0.at, references: $0.references)
        }
    }
}
