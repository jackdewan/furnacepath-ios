import XCTest

final class AuthFlowTests: XCTestCase {
    func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDemoExitReturnsToSignIn() {
        let app = XCUIApplication()
        app.launchArguments = ["--verify-screen", "auth-flow"]
        app.launch()
        let demo = app.buttons["Try the demo"]
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        capture("01-fresh-sign-in", app)
        demo.tap()
        let profile = app.buttons["open-profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 15))
        profile.tap()
        let exit = app.buttons["Exit demo"]
        XCTAssertTrue(exit.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Signed in with Apple"].exists)
        capture("02-demo-profile", app)
        exit.tap()
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Signed in with Apple"].exists)
        XCTAssertFalse(app.buttons["Sign out"].exists)
        capture("03-after-exit", app)
    }

    func testLearnFlowAdvancesCards() {
        let app = XCUIApplication()
        app.launchArguments = ["--verify-screen", "auth-flow"]
        app.launch()
        let demo = app.buttons["Try the demo"]
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        demo.tap()
        XCTAssertTrue(app.buttons["open-profile"].waitForExistence(timeout: 15))

        // Tap Unit 1 Lesson 1 to open the learn flow
        let lesson = app.buttons["unit-1-lesson-1"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 15))
        lesson.tap()

        // Should see the LEARN phase chip and first teaching card
        XCTAssertTrue(app.staticTexts["LEARN"].waitForExistence(timeout: 15))
        let cont = app.buttons["Continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 5))
        capture("learn-01-card-1", app)

        // Advance card 1 → card 2
        cont.tap()
        XCTAssertTrue(app.staticTexts["Card 2 of 2"].waitForExistence(timeout: 5))
        capture("learn-02-card-2", app)

        // Advance card 2 → transition
        app.buttons["Continue"].tap()
        let startQ = app.buttons["Start questions"]
        XCTAssertTrue(startQ.waitForExistence(timeout: 5))
        capture("learn-03-transition", app)

        // Start the quiz
        startQ.tap()
        let checkBtn = app.buttons["Check answer"]
        XCTAssertTrue(checkBtn.waitForExistence(timeout: 5))
        capture("learn-04-quiz", app)
    }

    func testDemoOpensLessonInNonCurrentUnit() {
        let app = XCUIApplication()
        app.launchArguments = ["--verify-screen", "auth-flow"]
        app.launch()
        let demo = app.buttons["Try the demo"]
        XCTAssertTrue(demo.waitForExistence(timeout: 15))
        demo.tap()
        XCTAssertTrue(app.buttons["open-profile"].waitForExistence(timeout: 15))

        let lesson = app.buttons["unit-2-lesson-1"]
        for _ in 0..<10 where !lesson.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(lesson.isHittable)
        // Move the row clear of the floating tab bar before tapping it.
        app.swipeUp()
        XCTAssertTrue(lesson.isHittable, app.debugDescription)
        lesson.tap()
        let title = app.staticTexts["lesson-screen-Price the Load · Lesson 1"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), app.debugDescription)
    }
}
