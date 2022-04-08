//
//  File.swift
//  MockCloudKitTestProjectUITests
//
//  Created by Christopher Charles Cavnor on 2/11/22.
//

import XCTest
import MockCloudKitFramework
@testable import MockCloudKitTestProject // required for access to CloudController and MCF protocols loaded by app
import CloudKit

class OnboardingUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()

        // Since UI tests are more expensive to run, it's usually a good idea
        // to exit if a failure was encountered
        continueAfterFailure = false

        app = XCUIApplication()

        // We send a command line argument to our app,
        // to enable it to reset its state
        app.launchArguments.append("--uitesting")
    }
    override func tearDown() {
        super.tearDown()
        // clear the environment
        app.launchEnvironment = [:]
    }

    // Take a screen shot - will be stored in /User/[username]/Library/Developer/Xcode/DerivedData
    // NOTE: use with care - images take up storage space.
    func takeScreenshot(name: String) {
      sleep(1)
      let fullScreenshot = XCUIScreen.main.screenshot()

      let screenshot = XCTAttachment(uniformTypeIdentifier: "public.png", name: "Screenshot-\(name)-\(UIDevice.current.name).png", payload: fullScreenshot.pngRepresentation, userInfo: nil)
      screenshot.lifetime = .keepAlways
      add(screenshot)
    }


    // MARK: - Tests

    func testAddMessageSuccess() {
        app.launch()
        // add a message
        app.textFields["messageBox"].tap()
        app.textFields["messageBox"].typeText("some message")

        // tap the submit button
        app.buttons["messageButton"].tap()
    }

    func testAddMessageError() {
        // set MCF error
        app.launchEnvironment = ["errorCode": "5"]
        app.launch()
        // alert button raised on CloudController.getMessages()
        XCTAssert(app.alerts.element.exists)
        app.alerts.element.tap()

        // add a message
        app.textFields["messageBox"].tap()
        app.textFields["messageBox"].typeText("some message")

        // tap the submit button
        app.buttons["messageButton"].tap()

        // alert button raised on CloudController.postMessage()
        XCTAssert(app.alerts.element.exists)
        app.alerts.element.tap()
    }
}
