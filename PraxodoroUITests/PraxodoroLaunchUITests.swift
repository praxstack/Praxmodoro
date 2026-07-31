import XCTest

final class PraxodoroLaunchUITests: XCTestCase {
  @MainActor
  func testLaunchesInitiateSurface() throws {
    let app = XCUIApplication()
    let stateRoot = FileManager.default.temporaryDirectory
      .appending(path: "PraxodoroUITests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: stateRoot, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: stateRoot) }

    app.launchEnvironment["PRAXODORO_STATE_ROOT"] = stateRoot.path
    app.launchArguments = ["-PraxodoroSmokeMode", "YES"]
    app.launch()

    XCTAssertTrue(
      app.staticTexts["initiate.heading"].waitForExistence(timeout: 5),
      "The native initiation heading must be visible after an isolated launch."
    )
  }
}
