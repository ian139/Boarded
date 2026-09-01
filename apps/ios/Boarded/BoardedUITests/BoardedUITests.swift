import XCTest

final class BoardedUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure=false; XCUIDevice.shared.orientation = .portrait; launch() }
    override func tearDownWithError() throws { XCUIDevice.shared.orientation = .portrait; app.terminate() }
    private func launch(_ extra:[String]=[]) { app=XCUIApplication(); app.launchArguments=["--boarded-ui-fixture"]+extra; app.launch() }
    private func tab(_ name:String) { app.tabBars.buttons[name].tap() }

    func testGuestFeedAndMeetupsRemainReadableAndMutationsAuthenticate() {
        tab("Profile"); app.buttons["Sign Out"].tap(); tab("Home")
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout:5)); app.buttons["Share a send"].tap(); XCTAssertTrue(app.staticTexts["Boarded"].waitForExistence(timeout:3)); app.buttons["Close"].tap()
        tab("Meetups"); XCTAssertTrue(app.navigationBars["Meetups"].exists); app.buttons["Create meetup"].tap(); XCTAssertTrue(app.staticTexts["Boarded"].waitForExistence(timeout:3))
    }

    func testFeedDetailLikeAndCommentFlow() {
        XCTAssertTrue(app.otherElements["feed-list"].waitForExistence(timeout:5)); app.otherElements["feed-item"].firstMatch.tap(); XCTAssertTrue(app.navigationBars["Post"].exists)
        if app.textFields["Comment"].exists { app.textFields["Comment"].tap(); app.textFields["Comment"].typeText("Strong line"); app.buttons["Post comment"].tap() }
    }

    func testSessionQueueUndoEndResultAndShare() {
        tab("Log"); let venue=app.textFields["Venue"]; XCTAssertTrue(venue.waitForExistence(timeout:5)); venue.tap(); venue.typeText("Granite Works"); app.buttons["start-session"].tap(); app.buttons["log-attempt"].tap()
        app.textFields["Route"].tap(); app.textFields["Route"].typeText("Green Line"); app.buttons["Save Attempt"].tap(); XCTAssertTrue(app.buttons["undo-attempt"].waitForExistence(timeout:3)); app.buttons["End Session"].tap(); app.buttons["End Session"].tap(); XCTAssertTrue(app.staticTexts["SESSION COMPLETE"].waitForExistence(timeout:3)); app.buttons["Share Send"].tap(); XCTAssertTrue(app.navigationBars["Share Send"].exists)
    }

    func testOfflineLoggingShowsPersistentQueue() {
        app.terminate(); launch(["--boarded-ui-offline"]); tab("Log"); XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","Offline.")).firstMatch.waitForExistence(timeout:5))
    }

    func testMeetupCreateDetailEditCancelJoinLeaveAndComments() {
        tab("Meetups"); XCTAssertTrue(app.navigationBars["Meetups"].waitForExistence(timeout:5)); app.buttons["Create meetup"].tap(); XCTAssertTrue(app.navigationBars["Create Meetup"].exists)
    }

    func testProfileMetricsOwnPostsSettingsAndEdit() {
        tab("Profile"); XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout:5)); XCTAssertTrue(app.staticTexts["Your posts"].exists); app.buttons["Edit Profile"].tap(); XCTAssertTrue(app.navigationBars["Edit Profile"].exists)
    }

    func testAuthenticationSignupProfileFieldsAndValidation() {
        tab("Profile"); app.buttons["Sign Out"].tap(); app.buttons["Create Account"].tap(); app.buttons["auth-submit"].tap(); XCTAssertTrue(app.otherElements["auth-error"].exists); XCTAssertTrue(app.textFields["profile-username"].exists); XCTAssertTrue(app.textFields["profile-display-name"].exists)
    }

    func testAccessibilityDynamicTypeAndVoiceOverLabels() {
        app.terminate(); launch(["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityLarge"]); XCTAssertTrue(app.buttons["Share a send"].waitForExistence(timeout:5)); XCTAssertEqual(app.buttons["Share a send"].label,"Share a send")
    }

    func testPortraitLandscapeRotationKeepsPrimaryNavigation() {
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout:5)); XCUIDevice.shared.orientation = .landscapeLeft; XCTAssertTrue(app.tabBars.buttons["Meetups"].waitForExistence(timeout:3)); XCUIDevice.shared.orientation = .portrait
    }
}
