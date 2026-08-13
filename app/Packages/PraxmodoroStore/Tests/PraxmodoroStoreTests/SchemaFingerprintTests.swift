import Foundation
import SwiftData
import Testing

@testable import PraxmodoroStore

/// The store schema, pinned by name (validator finding 8: the parity test
/// compares two containers built from the same code, so it cannot notice a
/// schema change at all — this golden string can). Growing the schema is a
/// deliberate act: change the fingerprint here in the same commit, with the
/// migration story in the message.
@Suite struct SchemaFingerprintTests {
    @Test func testSchemaFingerprintIsPinned() {
        let schema = Schema([
            SessionRecordModel.self, SessionEventModel.self,
            TaskRecordModel.self, CapacityReportModel.self,
        ])
        let fingerprint = schema.entities
            .map { entity in
                "\(entity.name)(\(entity.attributes.map(\.name).sorted().joined(separator: ",")))"
            }
            .sorted()
            .joined(separator: ";")
        #expect(
            fingerprint
                == "CapacityReportModel(at,id,sessionID,value);"
                + "SessionEventModel(at,id,kindRaw,orderIndex,payload,references,sessionID);"
                + "SessionRecordModel(id,policyName,startedAt);"
                + "TaskRecordModel(createdAt,firstAction,id,title)",
            "the persisted schema changed: \(fingerprint)")
    }
}
