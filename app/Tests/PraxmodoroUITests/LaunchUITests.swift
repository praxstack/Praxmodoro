import XCTest

@MainActor
func launchFresh(for testCase: XCTestCase) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
        "-ApplePersistenceIgnoreState", "YES",
        "-praxmodoro-ephemeral-store", "-praxmodoro-clean-window-state",
    ]
    app.terminate()
    app.launch()
    app.activate()
    testCase.addTeardownBlock { app.terminate() }
    return app
}

final class LaunchUITests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = launchFresh(for: self)
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    /// Spec: focus-loop-ui "Full keyboard loop" — begin a session with real
    /// key events (type the task, ⌘↩) and land on the focus surface.
    @MainActor
    func testKeyboardBeginReachesFocus() {
        let app = launchFresh(for: self)
        let taskField = app.textFields["task-input"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10), "fresh store must land on initiate")
        taskField.click()
        taskField.typeText("Edit the conference talk outline")
        app.typeKey(.return, modifierFlags: .command)
        // Focus surface: the task line renders and the companion field is
        // exposed to VoiceOver by its state label (SwiftUI merged elements
        // drop identifiers on macOS, so the label IS the queryable contract).
        XCTAssertTrue(
            app.staticTexts["task-line"].waitForExistence(timeout: 5),
            "⌘↩ must begin the session and land on the focus surface")
        let field = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'Companion:'")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the field must carry its VoiceOver state summary")
    }
}
