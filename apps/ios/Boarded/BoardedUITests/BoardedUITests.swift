import XCTest

final class BoardedUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        launch()
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    private func launch(_ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["--boarded-ui-fixture"] + extra
        app.launch()
    }

    private func tab(_ name: String) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRequiredStandardStateCaptures() {
        XCTAssertTrue(app.otherElements["feed-list"].waitForExistence(timeout: 5))
        capture("Home-standard")
        tab("Log")
        let venue = app.textFields["Venue"]
        XCTAssertTrue(venue.waitForExistence(timeout: 5))
        venue.tap(); venue.typeText("Granite Works")
        app.buttons["start-session"].tap()
        XCTAssertTrue(app.buttons["log-attempt"].waitForExistence(timeout: 5))
        capture("Active-logger-standard")
        app.buttons["log-attempt"].tap()
        app.textFields["Route"].tap(); app.textFields["Route"].typeText("Green Line")
        app.buttons["Save Attempt"].tap()
        app.buttons["End Session"].tap(); app.buttons["End Session"].tap()
        XCTAssertTrue(app.staticTexts["SESSION COMPLETE"].waitForExistence(timeout: 5))
        app.buttons["Share Send"].tap()
        XCTAssertTrue(app.navigationBars["Share Send"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Public"].exists)
        capture("Share-preview-standard")
        app.buttons["Close"].tap(); app.buttons["Done"].tap()
        tab("Meetups")
        app.staticTexts["Tuesday Granite Session"].tap()
        XCTAssertTrue(app.otherElements["meetup-detail"].waitForExistence(timeout: 5))
        capture("Meetup-detail-standard")
        tab("Profile")
        XCTAssertTrue(app.otherElements["profile-settings"].waitForExistence(timeout: 5))
        capture("Profile-standard")
    }

    func testRequiredAccessibilityStateCapturesAndDynamicTypeReflow() {
        app.terminate()
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge"])
        XCTAssertTrue(app.otherElements["feed-list"].waitForExistence(timeout: 5))
        capture("Home-accessibility-large")
        tab("Log")
        let venue = app.textFields["Venue"]
        venue.tap(); venue.typeText("Granite Works")
        app.buttons["start-session"].tap()
        XCTAssertTrue(app.buttons["log-attempt"].waitForExistence(timeout: 5))
        capture("Active-logger-accessibility-large")
        app.buttons["log-attempt"].tap()
        XCTAssertTrue(app.buttons["Sent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Fell"].exists)
        capture("Outcome-accessibility-large")
        app.textFields["Route"].tap(); app.textFields["Route"].typeText("Accessible Line")
        app.buttons["Save Attempt"].tap()
        app.buttons["End Session"].tap(); app.buttons["End Session"].tap()
        XCTAssertTrue(app.staticTexts["SESSION COMPLETE"].waitForExistence(timeout: 5))
        capture("Session-result-accessibility-large")
        app.buttons["Share Send"].tap()
        XCTAssertTrue(app.navigationBars["Share Send"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Public"].exists)
        capture("Share-preview-accessibility-large")
        app.buttons["Close"].tap(); app.buttons["Done"].tap()
        tab("Meetups")
        app.staticTexts["Tuesday Granite Session"].tap()
        XCTAssertTrue(app.otherElements["meetup-detail"].waitForExistence(timeout: 5))
        capture("Meetup-detail-accessibility-large")
        tab("Profile")
        XCTAssertTrue(app.otherElements["profile-settings"].waitForExistence(timeout: 5))
        capture("Profile-accessibility-large")
    }

    func testGuestPromptsForShareCommentAndMeetupMutations() {
        tab("Profile"); app.buttons["Sign Out"].tap(); tab("Home")
        app.buttons["Share a send"].tap()
        XCTAssertTrue(app.staticTexts["Boarded"].waitForExistence(timeout: 3)); app.buttons["Close"].tap()
        app.otherElements["feed-item"].firstMatch.tap()
        if app.buttons["comment-auth"].exists { app.buttons["comment-auth"].tap() }
        XCTAssertTrue(app.staticTexts["Boarded"].waitForExistence(timeout: 3)); app.buttons["Close"].tap()
        tab("Meetups"); app.buttons["Create meetup"].tap()
        XCTAssertTrue(app.staticTexts["Boarded"].waitForExistence(timeout: 3))
    }

    func testFeedLikeAndCommentUpdatesVisibleState() {
        XCTAssertTrue(app.otherElements["feed-list"].waitForExistence(timeout: 5))
        app.otherElements["feed-item"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Post"].waitForExistence(timeout: 5))
        let like = app.buttons["post-like"]
        XCTAssertTrue(like.exists); like.tap(); XCTAssertTrue(like.isSelected)
        let field = app.textFields["comment-field"]
        field.tap(); field.typeText("Strong line")
        app.buttons["comment-submit"].tap()
        XCTAssertTrue(app.staticTexts["Strong line"].waitForExistence(timeout: 3))
    }

    func testFellSentEndAndPublicShareCardFlow() {
        tab("Log")
        let venue = app.textFields["Venue"]
        XCTAssertTrue(venue.waitForExistence(timeout: 5)); venue.tap(); venue.typeText("Granite Works")
        app.buttons["start-session"].tap()
        app.buttons["log-attempt"].tap(); app.textFields["Route"].tap(); app.textFields["Route"].typeText("First Burn")
        app.buttons["Fell"].tap(); app.buttons["Save Attempt"].tap()
        XCTAssertTrue(app.staticTexts["Fell"].waitForExistence(timeout: 3))
        app.buttons["log-attempt"].tap(); app.textFields["Route"].tap(); app.textFields["Route"].typeText("Green Line")
        app.buttons["Sent"].tap(); app.buttons["Save Attempt"].tap()
        XCTAssertTrue(app.staticTexts["Sent"].waitForExistence(timeout: 3))
        app.buttons["End Session"].tap(); app.buttons["End Session"].tap()
        XCTAssertTrue(app.staticTexts["SESSION COMPLETE"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sends"].exists)
        app.buttons["Share Send"].tap()
        XCTAssertTrue(app.navigationBars["Share Send"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Public"].exists)
        XCTAssertTrue(app.staticTexts["Anyone can see this post."].exists)
    }

    func testOfflineAttemptSurvivesRelaunch() {
        app.terminate(); launch(["--boarded-ui-offline"]); tab("Log")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Offline.")).firstMatch.waitForExistence(timeout: 5))
        let venue = app.textFields["Venue"]
        venue.tap(); venue.typeText("Offline Crag"); app.buttons["start-session"].tap()
        app.buttons["log-attempt"].tap(); app.textFields["Route"].tap(); app.textFields["Route"].typeText("Saved Locally")
        app.buttons["Save Attempt"].tap()
        XCTAssertTrue(app.staticTexts["Saved Locally"].waitForExistence(timeout: 3))
        app.terminate(); launch(["--boarded-ui-offline"]); tab("Log")
        app.buttons["resume-session"].tap()
        XCTAssertTrue(app.staticTexts["Saved Locally"].waitForExistence(timeout: 5))
    }

    func testMeetupJoinLeaveCommentCreateAndCancel() {
        tab("Meetups")
        XCTAssertTrue(app.navigationBars["Meetups"].waitForExistence(timeout: 5))
        app.staticTexts["Tuesday Granite Session"].tap()
        XCTAssertTrue(app.otherElements["meetup-detail"].waitForExistence(timeout: 5))
        app.buttons["meetup-join"].tap(); XCTAssertTrue(app.buttons["meetup-leave"].waitForExistence(timeout: 3))
        app.buttons["meetup-leave"].tap(); XCTAssertTrue(app.buttons["meetup-join"].waitForExistence(timeout: 3))
        app.textFields["meetup-comment-field"].tap(); app.textFields["meetup-comment-field"].typeText("Bringing an extra pad")
        app.buttons["meetup-comment-submit"].tap()
        XCTAssertTrue(app.staticTexts["Bringing an extra pad"].waitForExistence(timeout: 3))
        app.navigationBars["Meetup"].buttons.element(boundBy: 0).tap()
        app.buttons["Create meetup"].tap()
        XCTAssertTrue(app.navigationBars["Create Meetup"].waitForExistence(timeout: 3))
        app.textFields["Title"].tap(); app.textFields["Title"].typeText("Saturday Circuit")
        app.textFields["Venue"].tap(); app.textFields["Venue"].typeText("Granite Works")
        app.textFields["Area"].tap(); app.textFields["Area"].typeText("North Shore")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Saturday Circuit"].waitForExistence(timeout: 5))
        app.staticTexts["Saturday Circuit"].tap(); app.buttons["meetup-cancel"].tap()
        XCTAssertTrue(app.buttons["Cancel Meetup"].waitForExistence(timeout: 3)); app.buttons["Cancel Meetup"].tap()
        XCTAssertTrue(app.staticTexts["Cancelled meetup"].waitForExistence(timeout: 3))
    }

    func testProfileSettingsPreferencesAndEdit() {
        tab("Profile")
        XCTAssertTrue(app.otherElements["profile-settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your posts"].exists)
        XCTAssertTrue(app.staticTexts["Climbing preferences"].exists)
        XCTAssertTrue(app.staticTexts["Accessibility"].exists)
        XCTAssertTrue(app.staticTexts["About"].exists)
        app.buttons["Edit Profile"].tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Display Name"].exists)
        XCTAssertTrue(app.textFields["Username"].exists)
    }

    func testReduceMotionAndLandscapeKeepPrimaryNavigationUsable() {
        app.terminate(); launch(["-UIAccessibilityReduceMotionEnabled", "YES"])
        XCTAssertTrue(app.buttons["Share a send"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.buttons["Meetups"].waitForExistence(timeout: 3))
        tab("Meetups"); XCTAssertTrue(app.navigationBars["Meetups"].exists)
        XCUIDevice.shared.orientation = .portrait
    }

    func testAuthenticationSignupProfileFieldsAndValidation() {
        tab("Profile"); app.buttons["Sign Out"].tap(); app.buttons["Create Account"].tap(); app.buttons["auth-submit"].tap()
        XCTAssertTrue(app.otherElements["auth-error"].exists)
        XCTAssertTrue(app.textFields["profile-username"].exists)
        XCTAssertTrue(app.textFields["profile-display-name"].exists)
    }
}
