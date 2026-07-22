import Foundation
import Testing

@testable import PraxodoroCore

@Suite("Timer reconciliation")
struct TimerReconciliationTests {
  @Test("idle projection is static and ignores a live observation")
  func idleProjectionIsStatic() throws {
    let projection = try SessionProjector.project(
      snapshot: .canonicalIdle,
      instant: SessionInstant(
        wallNow: Date(timeIntervalSinceReferenceDate: 100.75),
        liveProjection: LiveProjectionObservation(
          projectionToken: UUID(),
          rawWallAtProjectionAnchor: Date(timeIntervalSinceReferenceDate: .infinity),
          monotonicElapsedSinceAnchor: .seconds(-1)
        )
      )
    )

    #expect(projection.sourceRevision == 0)
    #expect(projection.sessionID == nil)
    #expect(projection.state == .idle)
    #expect(projection.task == nil)
    #expect(projection.firstAction == nil)
    #expect(projection.timingPolicy == nil)
    #expect(projection.phase == nil)
    #expect(projection.focusedSeconds == 0)
    #expect(projection.breakSeconds == 0)
    #expect(projection.remainingSeconds == nil)
    #expect(!projection.isPaused)
    #expect(!projection.isBoundaryAwaitingDecision)
    #expect(projection.nextScheduledCheckInAt == nil)
    #expect(projection.parkedThoughtCount == 0)
    #expect(!projection.lowCognitiveLoadEnabled)
  }
}
