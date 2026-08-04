import XCTest

/// The two interface-level follow-ups the independent M1 validator recorded:
/// keyboard coverage beyond `begin` as real key events, and a launch-time
/// first-run assertion.
///
/// Every session runs against `-praxmodoro-ephemeral-store`, so the real
/// Application Support store is never opened and the tests are hermetic.
final class KeyboardLoopUITests: XCTestCase {
    @MainActor
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-praxmodoro-ephemeral-store"]
        app.launch()
        return app
    }

    /// Spec: app-scaffold "Launch-time first-run assertion".
    @MainActor
    func testFirstRunLaunchPresentsOnlyTheStartPath() {
        let app = launchFresh()

        let taskField = app.textFields["task-input"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10), "a fresh store must land on the start path")
        XCTAssertTrue(app.textFields["first-action"].exists)
        XCTAssertTrue(app.buttons["begin-control"].exists)

        // Nothing from a running session may be present.
        XCTAssertFalse(app.staticTexts["task-line"].exists, "a running-session control appeared on first run")
        XCTAssertFalse(app.staticTexts["time-remaining"].exists, "a clock appeared with no session")

        // Begin stays disabled until a task is named.
        XCTAssertFalse(app.buttons["begin-control"].isEnabled, "begin must wait for a task")

        // No ambient surface opened itself: the capsule is launch-suppressed.
        XCTAssertFalse(app.windows["Focus capsule"].exists, "the capsule opened itself at launch")

        taskField.click()
        taskField.typeText("Edit the outline")
        XCTAssertTrue(app.buttons["begin-control"].isEnabled, "begin must enable once a task is named")
    }

    /// Spec: focus-loop-ui "Keyboard loop as real key events" — begin, the
    /// user-initiated check-in, each answer, the break end, and a new session,
    /// with no pointer interaction beyond focusing the first text field.
    @MainActor
    func testWholeLoopByKeyboard() {
        let app = launchFresh()

        let taskField = app.textFields["task-input"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10))
        taskField.click()
        taskField.typeText("Edit the conference talk outline")

        // Begin — ⌘↩
        app.typeKey(.return, modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["task-line"].waitForExistence(timeout: 5), "⌘↩ did not begin the session")

        // Check in — ⌘K — then answer "still fits" with 1, landing back on focus.
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["checkin-question"].waitForExistence(timeout: 5), "⌘K did not open the check-in")
        app.typeKey("1", modifierFlags: [])
        XCTAssertTrue(app.staticTexts["task-line"].waitForExistence(timeout: 5), "answer 1 did not return to focus")

        // Answers 2 and 3 also return to focus.
        for answer in ["2", "3"] {
            app.typeKey("k", modifierFlags: .command)
            XCTAssertTrue(app.staticTexts["checkin-question"].waitForExistence(timeout: 5))
            app.typeKey(answer, modifierFlags: [])
            XCTAssertTrue(app.staticTexts["task-line"].waitForExistence(timeout: 5), "answer \(answer) did not return to focus")
        }

        // Answer 4 asks for a break.
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["checkin-question"].waitForExistence(timeout: 5))
        app.typeKey("4", modifierFlags: [])
        XCTAssertTrue(app.staticTexts["break-suggestion"].waitForExistence(timeout: 5), "answer 4 did not start a break")

        // End the break — R — and the return overlay meets us.
        app.typeKey("r", modifierFlags: [])
        XCTAssertTrue(app.staticTexts["return-heading"].waitForExistence(timeout: 5), "R did not end the break into the return overlay")

        // Acknowledge — ⏎ — back to focus.
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["task-line"].waitForExistence(timeout: 5), "⏎ did not dismiss the return overlay")
        XCTAssertFalse(app.staticTexts["return-heading"].exists)

        // Answer 3 (drifted) also returns to focus rather than ending
        // anything — drift is information, not a failure.
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["checkin-question"].waitForExistence(timeout: 5))
        app.typeKey("3", modifierFlags: [])
        XCTAssertTrue(app.staticTexts["task-line"].waitForExistence(timeout: 5))

        // ⌘N's leg is covered by testNewSessionShortcutIsARealKeyEvent, which
        // needs a closed session to reach the review surface.
    }

    /// Spec: focus-loop-ui "Keyboard loop as real key events" — the ⌘N leg.
    /// The review surface is the only place a new session is offered, so this
    /// drives the loop to review and then presses ⌘N.
    @MainActor
    func testNewSessionShortcutIsARealKeyEvent() {
        let app = launchFresh()

        let taskField = app.textFields["task-input"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10))
        taskField.click()
        taskField.typeText("Edit the outline")
        app.typeKey(.return, modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["task-line"].waitForExistence(timeout: 5))

        // Reach review by keyboard — ⌘⇧W closes the session.
        app.typeKey("w", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["insight-card"].waitForExistence(timeout: 5), "⌘⇧W did not close the session into review")

        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.textFields["task-input"].waitForExistence(timeout: 5), "⌘N did not begin a new session")
    }

    /// Spec: companion-surfaces "Capsule toggles from the keyboard" and
    /// "Capsule is suppressed at launch".
    @MainActor
    func testCapsuleOpensAndClosesFromTheKeyboard() {
        let app = launchFresh()
        XCTAssertTrue(app.textFields["task-input"].waitForExistence(timeout: 10))

        let capsule = app.windows["Focus capsule"]
        XCTAssertFalse(capsule.exists, "the capsule opened itself at launch")

        app.typeKey("f", modifierFlags: [.command, .shift])
        XCTAssertTrue(capsule.waitForExistence(timeout: 5), "⌘⇧F did not open the capsule")

        app.typeKey("f", modifierFlags: [.command, .shift])
        let closed = NSPredicate(format: "exists == false")
        expectation(for: closed, evaluatedWith: capsule)
        waitForExpectations(timeout: 5)
    }
}
