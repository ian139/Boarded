import XCTest

final class BoardedUITests: XCTestCase {
    private var app: XCUIApplication!
    private let fixtureImageAlt = "Overhanging home bouldering wall with colorful holds and training volumes"
    private let offlineStoreID = UUID().uuidString

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
        if extra.contains("--boarded-ui-offline") {
            app.launchEnvironment["BOARDED_OFFLINE_STORE_ID"] = offlineStoreID
        }
        app.launch()
    }

    private func tab(_ name: String) {
        let tabBarButton = app.tabBars.buttons[name]
        if tabBarButton.waitForExistence(timeout: 1) {
            XCTAssertTrue(tabBarButton.isHittable)
            tabBarButton.tap()
            return
        }
        let candidates = app.buttons.matching(identifier: name)
        XCTAssertTrue(candidates.firstMatch.waitForExistence(timeout: 5))
        guard let fallback = candidates.allElementsBoundByIndex.first(where: \.isHittable) else {
            XCTFail("No visible, hittable \(name) navigation button")
            return
        }
        fallback.tap()
    }

    private var widthClassName: String {
        let width = app.windows.firstMatch.frame.width
        XCTAssertGreaterThan(width, 0, "Capture destination must expose a window width")
        return width >= 700 ? "regular" : "compact"
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(widthClassName)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func captureJournalMatrix(variant: String, route: String) {
        XCTAssertTrue(app.otherElements["feed-list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images[fixtureImageAlt].exists)
        if variant.contains("accessibility-large") {
            XCTAssertTrue(app.descendants(matching: .any)["session-facts-continuation"].exists)
        }
        let timeline = app.descendants(matching: .any)["session-attempt-timeline"].firstMatch
        XCTAssertTrue(timeline.exists)
        XCTAssertTrue(timeline.label.contains("Sent"))
        XCTAssertTrue(timeline.label.contains("Fell"))
        XCTAssertTrue(timeline.label.contains("Stopped"))
        XCTAssertTrue(timeline.label.contains("Attempt 48, Stopped"))
        if !variant.contains("accessibility-large") {
            let preview = app.descendants(matching: .any)["canonical-session-artwork-preview"].firstMatch
            XCTAssertTrue(preview.exists)
            XCTAssertLessThanOrEqual(timeline.frame.maxY, preview.frame.maxY)
            let featuredRoute = app.descendants(matching: .any)["session-featured-route"].firstMatch
            XCTAssertTrue(featuredRoute.exists)
            XCTAssertLessThanOrEqual(featuredRoute.frame.maxY, preview.frame.maxY)
        }
        capture("\(variant)-Home")

        tab("Log")
        let venue = app.textFields["Venue"]
        XCTAssertTrue(venue.waitForExistence(timeout: 5))
        venue.tap(); app.typeText("Home Board")
        app.buttons["start-session"].tap()
        XCTAssertTrue(app.buttons["log-attempt"].waitForExistence(timeout: 5))
        capture("\(variant)-Active-logger")

        app.buttons["log-attempt"].tap()
        XCTAssertTrue(app.textFields["Route"].waitForExistence(timeout: 5))
        app.textFields["Route"].tap(); app.typeText(route)
        app.buttons["Save Attempt"].tap()
        app.buttons["End Session"].tap()
        let confirmation = app.buttons["confirm-end-session"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
        XCTAssertTrue(app.descendants(matching: .any)["session-result"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Session Complete"].exists)
        XCTAssertTrue(app.images[fixtureImageAlt].waitForExistence(timeout: 5))
        capture("\(variant)-Session-result")

        app.buttons["Share session"].tap()
        XCTAssertTrue(app.navigationBars["Share session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["session-preview"].exists)
        XCTAssertTrue(app.images[fixtureImageAlt].exists)
        if variant.contains("accessibility-large") {
            let sessionSelector = app.descendants(matching: .any)["share-session"].firstMatch
            let attemptSelector = app.descendants(matching: .any)["share-featured-attempt"].firstMatch
            XCTAssertGreaterThanOrEqual(sessionSelector.frame.height, 88)
            XCTAssertGreaterThanOrEqual(attemptSelector.frame.height, 88)
            XCTAssertTrue(app.descendants(matching: .any)["share-scroll-affordance"].exists)
        }
        if variant.contains("accessibility-large") {
            let continuation = app.descendants(matching: .any)["session-facts-continuation"].firstMatch
            if !continuation.exists { app.swipeUp() }
            if !continuation.exists { app.swipeUp() }
            XCTAssertTrue(continuation.waitForExistence(timeout: 3))
        } else {
            XCTAssertTrue(app.descendants(matching: .any)["session-facts-overlay"].firstMatch.exists)
        }
        capture("\(variant)-Share-preview")
        app.buttons["Close"].tap(); app.buttons["Done"].tap()

        tab("Meetups")
        app.staticTexts["Tuesday Granite Session"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["meetup-detail"].waitForExistence(timeout: 5))
        capture("\(variant)-Meetup-detail")

        tab("Profile")
        XCTAssertTrue(app.descendants(matching: .any)["profile-settings"].waitForExistence(timeout: 5))
        capture("\(variant)-Profile")
    }

    func testRequiredStandardStateCaptures() {
        captureJournalMatrix(variant: "standard", route: "Green Line")
    }

    func testRequiredAccessibilityStateCapturesAndDynamicTypeReflow() {
        app.terminate()
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge"])
        captureJournalMatrix(variant: "accessibility-large", route: "Accessible Line")
    }

    func testReduceTransparencyIncreaseContrastStandardCaptures() {
        app.terminate()
        launch([
            "-UIAccessibilityReduceTransparencyEnabled", "YES",
            "-UIAccessibilityDarkerSystemColorsEnabled", "YES"
        ])
        captureJournalMatrix(
            variant: "standard-reduce-transparency-increase-contrast",
            route: "Opaque Circuit"
        )
    }

    func testReduceTransparencyIncreaseContrastAccessibilityCaptures() {
        app.terminate()
        launch([
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge",
            "-UIAccessibilityReduceTransparencyEnabled", "YES",
            "-UIAccessibilityDarkerSystemColorsEnabled", "YES"
        ])
        captureJournalMatrix(
            variant: "accessibility-large-reduce-transparency-increase-contrast",
            route: "Contrast Circuit"
        )
    }

    func testGuestPromptsForShareCommentAndMeetupMutations() {
        tab("Profile")
        app.buttons["Sign Out"].tap()
        XCTAssertTrue(app.buttons["Create Account"].waitForExistence(timeout: 5))
        tab("Home")
        app.buttons["Share a session"].tap()
        XCTAssertTrue(app.staticTexts["Boarded"].waitForExistence(timeout: 3)); app.buttons["Close"].tap()
        app.descendants(matching: .any)["feed-item"].firstMatch.tap()
        if app.buttons["comment-auth"].exists { app.buttons["comment-auth"].tap() }
        XCTAssertTrue(app.staticTexts["Boarded"].waitForExistence(timeout: 3)); app.buttons["Close"].tap()
        tab("Meetups"); app.buttons["Create meetup"].tap()
        XCTAssertTrue(app.staticTexts["Boarded"].waitForExistence(timeout: 3))
    }

    func testFeedLikeAndCommentUpdatesVisibleState() {
        XCTAssertTrue(app.otherElements["feed-list"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["feed-item"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Session journal"].waitForExistence(timeout: 5))
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
        app.buttons["End Session"].tap(); app.buttons["confirm-end-session"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["session-result"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Session Complete"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["session-result-sends"].firstMatch.exists)
        app.buttons["Share session"].tap()
        XCTAssertTrue(app.navigationBars["Share session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["share-featured-attempt"].exists)
        XCTAssertTrue(
            app.buttons["share-featured-attempt"].label.contains("Green Line"),
            "Result handoff must preserve the exact featured attempt"
        )
        XCTAssertTrue(app.segmentedControls["share-overlay"].exists)
        XCTAssertTrue(app.buttons["share-photo"].exists)
        XCTAssertTrue(app.textFields["Photo description"].exists)
        XCTAssertTrue(app.buttons["publish-session"].isEnabled)
        app.buttons["publish-session"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["share-success"].waitForExistence(timeout: 8))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["session-result"].waitForExistence(timeout: 5))
        app.buttons["Done"].firstMatch.tap()
        tab("Home")
        XCTAssertTrue(app.otherElements["feed-list"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.descendants(matching: .any).matching(identifier: "feed-item").count, 2)
        XCTAssertGreaterThanOrEqual(app.images.matching(NSPredicate(format: "label == %@", fixtureImageAlt)).count, 2)
        let publishedArtwork = app.images.matching(
            NSPredicate(
                format: "label == %@ AND value CONTAINS %@",
                fixtureImageAlt,
                "Venue Granite Works"
            )
        ).firstMatch
        XCTAssertTrue(publishedArtwork.waitForExistence(timeout: 5))
        let publishedFacts = publishedArtwork.value as? String ?? ""
        XCTAssertTrue(publishedFacts.contains("Venue Granite Works"))
        XCTAssertTrue(publishedFacts.contains("Duration "))
        XCTAssertTrue(publishedFacts.contains("2 attempts"))
        XCTAssertTrue(publishedFacts.contains("1 sends"))
        XCTAssertTrue(publishedFacts.contains("Featured attempt V0 Green Line, Sent"))
    }

    func testOfflineAttemptSurvivesRelaunch() {
        app.terminate(); launch(["--boarded-ui-offline"]); tab("Log")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Offline.")).firstMatch.waitForExistence(timeout: 5))
        let venue = app.textFields["Venue"]
        XCTAssertTrue(venue.waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.descendants(matching: .any)["meetup-detail"].waitForExistence(timeout: 5))
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
        let cancelConfirmation = app.buttons["confirm-cancel-meetup"].firstMatch
        XCTAssertTrue(cancelConfirmation.waitForExistence(timeout: 3)); cancelConfirmation.tap()
        XCTAssertTrue(app.staticTexts["Cancelled meetup"].waitForExistence(timeout: 3))
    }

    func testProfileSettingsPreferencesAndEdit() {
        tab("Profile")
        XCTAssertTrue(app.descendants(matching: .any)["profile-settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Session journal"].exists)
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
        XCTAssertTrue(app.buttons["Share a session"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.buttons["Meetups"].waitForExistence(timeout: 3))
        tab("Meetups"); XCTAssertTrue(app.navigationBars["Meetups"].exists)
        XCUIDevice.shared.orientation = .portrait
    }

    func testAuthenticationSignupProfileFieldsAndValidation() {
        tab("Profile")
        app.buttons["Sign Out"].tap()
        XCTAssertTrue(app.buttons["Create Account"].waitForExistence(timeout: 5))
        app.buttons["Create Account"].tap(); app.buttons["auth-submit"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["auth-error"].exists)
        XCTAssertTrue(app.textFields["profile-username"].exists)
        XCTAssertTrue(app.textFields["profile-display-name"].exists)
    }
}
