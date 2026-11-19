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
}
