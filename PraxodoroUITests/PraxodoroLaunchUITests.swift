import CoreGraphics
import XCTest

final class PraxodoroLaunchUITests: XCTestCase {
  @MainActor
  func testLaunchesInitiateSurface() throws {
    let app = XCUIApplication()
    let stateRoot = FileManager.default.temporaryDirectory
      .appending(path: "PraxodoroUITests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: stateRoot, withIntermediateDirectories: true)
    let originalCursorPosition = CGEvent(source: nil)?.location
    addTeardownBlock {
      if let originalCursorPosition {
        _ = CGWarpMouseCursorPosition(originalCursorPosition)
      }
      try? FileManager.default.removeItem(at: stateRoot)
    }

    let mainDisplay = CGDisplayBounds(CGMainDisplayID())
    XCTAssertEqual(
      CGWarpMouseCursorPosition(CGPoint(x: mainDisplay.midX, y: mainDisplay.midY)),
      .success,
      "The UI-test launch must be anchored to the main display."
    )

    app.launchEnvironment["PRAXODORO_STATE_ROOT"] = stateRoot.path
    app.launchEnvironment["CFFIXED_USER_HOME"] = stateRoot.path
    app.launchArguments = [
      "-ApplePersistenceIgnoreState", "YES",
      "-PraxodoroSmokeMode", "YES",
    ]
    app.launch()

    XCTAssertTrue(
      app.staticTexts["initiate.heading"].waitForExistence(timeout: 5),
      "The native initiation heading must be visible after an isolated launch."
    )
  }
}
