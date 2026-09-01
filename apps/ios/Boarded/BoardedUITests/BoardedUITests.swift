import XCTest

final class BoardedUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--boarded-ui-fixture"]
        app.launch()
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
        app = nil
    }

    private func relaunch(fixture state: String? = nil) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--boarded-ui-fixture"] + (state.map { [$0] } ?? [])
        app.launch()
    }

    private func capture(_ name: String, after element: XCUIElement, timeout: TimeInterval = 10) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing rendered state anchor for \(name)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func primaryTab(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", name))
            .firstMatch
    }

    func testRenderedStateFixtures() throws {
        capture("home-list", after: app.staticTexts["Granite Drift"])

        app.staticTexts["Granite Drift"].tap()
        capture("home-route-detail", after: app.otherElements["Route detail popup"])

        app.buttons["Route actions"].tap()
        XCTAssertTrue(app.buttons["Edit Route"].waitForExistence(timeout: 5))
        app.buttons["Edit Route"].tap()
        let editorCanvas = app.descendants(matching: .any)["Editor canvas surface"]
        capture("topo-editor", after: editorCanvas)

        app.buttons["Browse topo"].tap()
        let browseCanvas = app.descendants(matching: .any)
            .matching(identifier: "Editor canvas surface")
            .matching(NSPredicate(format: "label == %@", "Topo wall"))
            .firstMatch
        capture("topo-browse", after: browseCanvas)

        relaunch()
        XCTAssertTrue(app.staticTexts["Granite Drift"].waitForExistence(timeout: 10))
        primaryTab("Profile").tap()
        let settingsLink = app.staticTexts["Settings"]
        app.swipeUp()
        capture("profile", after: settingsLink)

        settingsLink.tap()
        let dataSection = app.staticTexts["Your climbing data"]
        app.swipeUp()
        app.swipeUp()
        capture("settings", after: dataSection)

        relaunch(fixture: "log-active")
        capture("log-active", after: app.staticTexts["ACTIVE SESSION"])

        relaunch(fixture: "log-offline")
        capture(
            "log-offline",
            after: app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Offline. Attempts remain saved"))
                .firstMatch
        )

        relaunch(fixture: "log-result")
        capture("log-result", after: app.staticTexts["Route sent"])
    }

    func testFixtureLaunchRoutesDetailAndSelectors() throws {
        XCTAssertTrue(app.staticTexts["1 route"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Granite Drift"].waitForExistence(timeout: 10))
        let usesDirectSelectorControls = app.buttons["Newest"].exists
        if usesDirectSelectorControls {
            XCTAssertTrue(app.buttons["All Grades"].exists)
            XCTAssertTrue(app.buttons["Fixture Slab"].exists)
        } else {
            XCTAssertTrue(app.buttons["Sort routes"].exists)
            XCTAssertTrue(app.buttons["Filter by grade"].exists)
            XCTAssertTrue(app.buttons["Filter by wall"].exists)
        }

        app.staticTexts["Granite Drift"].tap()
        let popup = app.otherElements["Route detail popup"]
        XCTAssertTrue(popup.waitForExistence(timeout: 5))

        let routeSections = [
            app.descendants(matching: .any)["Route wall"],
            app.descendants(matching: .any)["Route details"],
            app.descendants(matching: .any)["Route stats"],
            app.descendants(matching: .any)["Route actions row"],
            app.descendants(matching: .any)["Comments section"]
        ]
        for section in routeSections {
            XCTAssertTrue(section.waitForExistence(timeout: 5), "Missing route detail section \(section)")
        }
        for (upper, lower) in zip(routeSections, routeSections.dropFirst()) {
            XCTAssertLessThan(
                upper.frame.minY,
                lower.frame.minY,
                "Route detail sections must be vertically ordered."
            )
        }
        XCTAssertTrue(app.buttons["Like"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Log Send"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.tabBars.buttons["Home"].exists)

        let commentsButton = app.buttons["Comments"]
        XCTAssertTrue(commentsButton.waitForExistence(timeout: 3))
        commentsButton.tap()
        XCTAssertTrue(app.staticTexts["No comments yet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["Comment"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Mark Beta"].waitForExistence(timeout: 3))
        let postButton = app.buttons["Post"]
        XCTAssertTrue(postButton.waitForExistence(timeout: 3))
        XCTAssertFalse(postButton.isEnabled)

        XCTAssertTrue(app.buttons["Close route"].waitForExistence(timeout: 3))
        app.buttons["Close route"].tap()
        if usesDirectSelectorControls {
            XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        }

        if usesDirectSelectorControls {
            app.buttons["Name"].tap()
            XCTAssertTrue(app.staticTexts["Granite Drift"].waitForExistence(timeout: 3))
        } else {
            let wallFilter = app.buttons["Filter by wall"]
            XCTAssertEqual(wallFilter.value as? String, "Fixture Slab")
            wallFilter.tap()
            XCTAssertTrue(app.buttons["All Walls"].waitForExistence(timeout: 3))
            app.buttons["All Walls"].tap()
            XCTAssertEqual(wallFilter.value as? String, "All Walls")

            let gradeFilter = app.buttons["Filter by grade"]
            gradeFilter.tap()
            XCTAssertTrue(app.buttons["V4"].waitForExistence(timeout: 3))
            app.buttons["V4"].tap()
            XCTAssertEqual(gradeFilter.value as? String, "V4")

            app.buttons["Sort routes"].tap()
            XCTAssertTrue(app.buttons["Sort: Name"].waitForExistence(timeout: 3))
            app.buttons["Sort: Name"].tap()
            XCTAssertEqual(app.buttons["Sort routes"].value as? String, "Sort: Name")
        }
    }

    func testFixtureTabsProfileSettingsAppearanceAndOrientation() throws {
        XCTAssertTrue(app.staticTexts["1 route"].waitForExistence(timeout: 10))

        primaryTab("Profile").tap()
        app.buttons["Edit profile"].tap()
        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 3))
        let fullName = app.textFields["Full name"]
        XCTAssertTrue(fullName.waitForExistence(timeout: 3))
        fullName.tap()
        fullName.typeText(" Edited")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Fixture Climber Edited"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Settings"].exists)

        app.staticTexts["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let appearance = app.descendants(matching: .any)["Appearance setting"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 3))
        XCTAssertEqual(appearance.value as? String, "Dark")
        let manageWalls = app.buttons["Manage Walls"]
        if !manageWalls.exists {
            app.swipeUp()
        }
        XCTAssertTrue(manageWalls.waitForExistence(timeout: 5))
        XCTAssertTrue(manageWalls.label.localizedCaseInsensitiveContains("2 walls"))

        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(window.frame.width, window.frame.height)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
    }

    func testFixtureEditorWallAndHoldControlsAreDeterministic() throws {
        XCTAssertTrue(app.staticTexts["1 route"].waitForExistence(timeout: 10))
        primaryTab("Topo").tap()
        XCTAssertTrue(app.staticTexts["Hold count"].waitForExistence(timeout: 10))

        // Holds are inferred from canvas touches; the old explicit selectors are gone.
        let removedEditorControls = [
            "Add Start hold",
            "Add Hand hold",
            "Add Foot hold",
            "Add Finish hold",
            "Pan tool",
            "Selected mode"
        ]
        for identifier in removedEditorControls {
            XCTAssertFalse(app.buttons[identifier].exists, "\(identifier) must not be exposed.")
        }
    }
    func testFixtureWallCreateAndDeleteStayInMemory() throws {
        let name = "UI Fixture Wall \(UUID().uuidString)"
        XCTAssertTrue(app.staticTexts["1 route"].waitForExistence(timeout: 10))
        primaryTab("Profile").tap()
        app.staticTexts["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let manageWalls = app.buttons["Manage Walls"]
        for _ in 0..<6 where !manageWalls.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(manageWalls.waitForExistence(timeout: 5))
        XCTAssertTrue(manageWalls.label.localizedCaseInsensitiveContains("2 walls"))
        manageWalls.tap()
        let wallsList = app.collectionViews["Wall manager"]
        XCTAssertTrue(wallsList.waitForExistence(timeout: 5))
        wallsList.swipeUp()

        let nameField = app.textFields["Wall name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(name)
        app.buttons["Add Wall"].tap()
        wallsList.swipeDown()
        wallsList.swipeDown()
        XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons[name].value as? String, "Selected")
        let renamed = "\(name) Renamed"
        let createdWall = app.buttons[name]
        createdWall.swipeLeft()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 3))
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Wall"].waitForExistence(timeout: 5))
        let editNameField = app.textFields["Edit wall name"]
        XCTAssertTrue(editNameField.waitForExistence(timeout: 3))
        editNameField.tap()
        editNameField.press(forDuration: 1.0)
        let selectAll = app.menuItems["Select All"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 3))
        selectAll.tap()
        editNameField.typeText(renamed)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Edit Wall"].waitForNonExistence(timeout: 5))
        let renamedWall = app.buttons[renamed]
        XCTAssertTrue(renamedWall.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons[name].exists)
        renamedWall.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()
        XCTAssertTrue(renamedWall.waitForNonExistence(timeout: 5))
    }
    func testFixtureEditorHoldGesturesAndRouteCreate() throws {
        let routeName = "UI Fixture Route \(UUID().uuidString)"
        XCTAssertTrue(app.staticTexts["1 route"].waitForExistence(timeout: 10))
        primaryTab("Topo").tap()
        let canvas = app.descendants(matching: .any)["Editor canvas surface"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))

        func radius(from value: String?) -> Int? {
            guard let value,
                  let component = value.split(separator: ",").last,
                  let number = component.split(separator: " ").first else {
                return nil
            }
            return Int(number)
        }

        func position(from value: String?) -> (x: Int, y: Int)? {
            guard let value else { return nil }
            let components = value.split(separator: ",")
            guard components.count >= 2,
                  let x = Int(components[0].split(separator: " ").first ?? ""),
                  let y = Int(components[1].split(separator: " ").first ?? "") else {
                return nil
            }
            return (x, y)
        }

        func zoom(from value: String?) -> Int? {
            guard let value else { return nil }
            let components = value.split(separator: " ")
            guard let zoomIndex = components.firstIndex(of: "zoom"),
                  components.index(after: zoomIndex) < components.endIndex else {
                return nil
            }
            return Int(components[components.index(after: zoomIndex)])
        }

        // Empty-canvas taps place the default Start type without a tool selection.
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).tap()
        XCTAssertTrue((canvas.value as? String)?.contains("1 hold") == true)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)).tap()
        XCTAssertTrue((canvas.value as? String)?.contains("2 holds") == true)

        let firstMarker = app.descendants(matching: .any)["Editor hold 1"]
        let secondMarker = app.descendants(matching: .any)["Editor hold 2"]
        XCTAssertTrue(firstMarker.waitForExistence(timeout: 5))
        XCTAssertTrue(secondMarker.waitForExistence(timeout: 5))
        XCTAssertTrue(firstMarker.label.localizedCaseInsensitiveContains("start"))
        XCTAssertTrue(secondMarker.label.localizedCaseInsensitiveContains("start"))
        XCTAssertFalse(firstMarker.label.localizedCaseInsensitiveContains("selected"))
        XCTAssertTrue((firstMarker.value as? String)?.contains("percent x") == true)

        guard let secondInitialRadius = radius(from: secondMarker.value as? String),
              let secondInitialPosition = position(from: secondMarker.value as? String),
              let initialCanvasZoom = zoom(from: canvas.value as? String) else {
            return XCTFail("The surviving hold and canvas must expose their initial geometry.")
        }

        // A marker cycles Start → Hand → Foot → Finish → delete without a selector.
        firstMarker.tap()
        XCTAssertTrue(firstMarker.label.localizedCaseInsensitiveContains("hand"))
        firstMarker.tap()
        XCTAssertTrue(firstMarker.label.localizedCaseInsensitiveContains("foot"))
        firstMarker.tap()
        XCTAssertTrue(firstMarker.label.localizedCaseInsensitiveContains("finish"))
        firstMarker.tap()
        XCTAssertTrue((canvas.value as? String)?.contains("1 hold") == true)

        // Reacquire the surviving marker after deletion; it starts as Start.
        let survivingMarker = app.descendants(matching: .any)["Editor hold 1"]
        XCTAssertTrue(survivingMarker.waitForExistence(timeout: 5))
        XCTAssertTrue(survivingMarker.label.localizedCaseInsensitiveContains("start"))
        survivingMarker.tap()
        XCTAssertTrue(survivingMarker.label.localizedCaseInsensitiveContains("hand"))

        // A further empty-canvas tap still defaults to Start.
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        XCTAssertTrue((canvas.value as? String)?.contains("2 holds") == true)

        let addedMarker = app.descendants(matching: .any)["Editor hold 2"]
        XCTAssertTrue(addedMarker.waitForExistence(timeout: 5))
        XCTAssertTrue(addedMarker.label.localizedCaseInsensitiveContains("start"))
        XCTAssertFalse(survivingMarker.label.localizedCaseInsensitiveContains("selected"))

        guard let addedInitialRadius = radius(from: addedMarker.value as? String),
              let addedInitialPosition = position(from: addedMarker.value as? String) else {
            return XCTFail("The added hold must expose its initial radius and position.")
        }

        // A marker pinch changes only that marker.
        survivingMarker.pinch(withScale: 1.6, velocity: 1.0)
        guard let survivingResizedRadius = radius(from: survivingMarker.value as? String),
              let addedAfterMarkerPinchRadius = radius(from: addedMarker.value as? String),
              let survivingPositionAfterPinch = position(from: survivingMarker.value as? String),
              let addedPositionAfterPinch = position(from: addedMarker.value as? String),
              let canvasZoomAfterMarkerPinch = zoom(from: canvas.value as? String) else {
            return XCTFail("Both holds and canvas must expose geometry after marker pinch.")
        }
        XCTAssertGreaterThan(survivingResizedRadius, secondInitialRadius)
        XCTAssertEqual(addedAfterMarkerPinchRadius, addedInitialRadius)
        XCTAssertEqual(canvasZoomAfterMarkerPinch, initialCanvasZoom)
        XCTAssertEqual(survivingPositionAfterPinch.x, secondInitialPosition.x)
        XCTAssertEqual(survivingPositionAfterPinch.y, secondInitialPosition.y)
        XCTAssertEqual(addedPositionAfterPinch.x, addedInitialPosition.x)
        XCTAssertEqual(addedPositionAfterPinch.y, addedInitialPosition.y)
        XCTAssertTrue(survivingMarker.label.localizedCaseInsensitiveContains("hand"))

        // A one-finger drag begun on a marker must not move either hold or create another.
        let dragStart = survivingMarker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        dragStart.press(
            forDuration: 0.1,
            thenDragTo: dragStart.withOffset(CGVector(dx: 90, dy: 30))
        )
        guard let survivingPositionAfterDrag = position(from: survivingMarker.value as? String),
              let addedPositionAfterDrag = position(from: addedMarker.value as? String) else {
            return XCTFail("Both holds must expose positions after marker drag.")
        }
        XCTAssertEqual(survivingPositionAfterDrag.x, secondInitialPosition.x)
        XCTAssertEqual(survivingPositionAfterDrag.y, secondInitialPosition.y)
        XCTAssertEqual(addedPositionAfterDrag.x, addedInitialPosition.x)
        XCTAssertEqual(addedPositionAfterDrag.y, addedInitialPosition.y)
        XCTAssertTrue((canvas.value as? String)?.contains("2 holds") == true)
        XCTAssertTrue(survivingMarker.label.localizedCaseInsensitiveContains("hand"))

        // Reset returns canvas zoom to its initial value without creating a hold.
        canvas.pinch(withScale: 1.4, velocity: 1.0)
        guard let canvasZoomBeforeReset = zoom(from: canvas.value as? String) else {
            return XCTFail("Canvas must expose zoom after pinch.")
        }
        XCTAssertGreaterThan(canvasZoomBeforeReset, initialCanvasZoom)
        XCTAssertTrue((canvas.value as? String)?.contains("2 holds") == true)
        let resetButton = app.buttons["Reset wall zoom"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3))
        resetButton.tap()
        XCTAssertEqual(zoom(from: canvas.value as? String), initialCanvasZoom)
        XCTAssertTrue((canvas.value as? String)?.contains("2 holds") == true)

        app.buttons["Editor save route"].tap()
        let routeNameField = app.textFields["Route name"]
        XCTAssertTrue(routeNameField.waitForExistence(timeout: 3))
        routeNameField.tap()
        routeNameField.typeText(routeName)
        app.buttons["Route form save"].tap()
        XCTAssertTrue(primaryTab("Home").waitForExistence(timeout: 5))
        primaryTab("Home").tap()
        XCTAssertTrue(app.staticTexts[routeName].waitForExistence(timeout: 10))
        app.staticTexts[routeName].tap()
        XCTAssertTrue(app.otherElements["Route detail popup"].waitForExistence(timeout: 5))
        app.buttons["Route actions"].tap()
        app.buttons["Edit Route"].tap()

        let persistedFirstMarker = app.descendants(matching: .any)["Editor hold 1"]
        let persistedSecondMarker = app.descendants(matching: .any)["Editor hold 2"]
        XCTAssertTrue(persistedFirstMarker.waitForExistence(timeout: 5))
        XCTAssertTrue(persistedSecondMarker.waitForExistence(timeout: 5))
        XCTAssertTrue(persistedFirstMarker.label.localizedCaseInsensitiveContains("hand"))
        XCTAssertTrue(persistedSecondMarker.label.localizedCaseInsensitiveContains("start"))
        XCTAssertEqual(radius(from: persistedFirstMarker.value as? String), survivingResizedRadius)
        XCTAssertEqual(radius(from: persistedSecondMarker.value as? String), addedInitialRadius)
        guard let persistedFirstPosition = position(from: persistedFirstMarker.value as? String),
              let persistedSecondPosition = position(from: persistedSecondMarker.value as? String) else {
            return XCTFail("Both persisted holds must expose their positions.")
        }
        XCTAssertEqual(persistedFirstPosition.x, secondInitialPosition.x)
        XCTAssertEqual(persistedFirstPosition.y, secondInitialPosition.y)
        XCTAssertEqual(persistedSecondPosition.x, addedInitialPosition.x)
        XCTAssertEqual(persistedSecondPosition.y, addedInitialPosition.y)
    }

    func testFixtureRouteReadUpdateReopenAndDelete() throws {
        let updatedName = "Granite Drift Updated"
        XCTAssertTrue(app.staticTexts["1 route"].waitForExistence(timeout: 10))
        app.staticTexts["Granite Drift"].tap()
        XCTAssertTrue(app.otherElements["Route detail popup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Granite Drift"].exists)
        app.buttons["Route actions"].tap()
        app.buttons["Edit Route"].tap()
        let editorSave = app.buttons["Editor save route"]
        XCTAssertTrue(editorSave.waitForExistence(timeout: 5))
        let editorSaveEnabled = expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: editorSave
        )
        wait(for: [editorSaveEnabled], timeout: 5)
        editorSave.tap()
        let routeNameField = app.textFields["Route name"]
        XCTAssertTrue(routeNameField.waitForExistence(timeout: 3))
        routeNameField.tap()
        routeNameField.typeText(" Updated")
        app.buttons["Route form save"].tap()
        XCTAssertTrue(app.staticTexts[updatedName].waitForExistence(timeout: 8))
        app.staticTexts[updatedName].tap()
        XCTAssertTrue(app.otherElements["Route detail popup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[updatedName].exists)
        app.buttons["Route actions"].tap()
        XCTAssertTrue(app.buttons["Delete Route"].waitForExistence(timeout: 3))
        app.buttons["Delete Route"].tap()
        XCTAssertTrue(app.buttons["Delete Route"].waitForExistence(timeout: 3))
        app.buttons["Delete Route"].tap()
        XCTAssertTrue(app.staticTexts[updatedName].waitForNonExistence(timeout: 8))
    }
    func testFixtureLogoutAndSignInStayLocal() throws {
        XCTAssertTrue(app.staticTexts["1 route"].waitForExistence(timeout: 10))
        primaryTab("Profile").tap()
        app.staticTexts["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let accountAccess = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", "Account access")
        ).firstMatch
        XCTAssertTrue(accountAccess.waitForExistence(timeout: 5))
        accountAccess.tap()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        let logOut = app.buttons["Log Out"]
        XCTAssertTrue(logOut.waitForExistence(timeout: 3))
        logOut.tap()
        XCTAssertTrue(app.staticTexts["Welcome back"].waitForExistence(timeout: 5))

        let email = app.textFields["you@example.com"]
        let password = app.secureTextFields["password"]
        email.tap()
        email.typeText("fixture@boarded.test")
        password.tap()
        password.typeText("fixture-password")
        app.buttons["Log In"].tap()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fixture Climber"].waitForExistence(timeout: 5))
    }
}
