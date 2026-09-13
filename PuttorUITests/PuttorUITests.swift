//
//  PuttorUITests.swift
//  PuttorUITests
//
//  Created by Paul Kaineder on 23.07.26.
//

import XCTest

final class PuttorUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    /// Turning to landscape and back must leave the statistics tab as wide as
    /// it was; it used to come back zoomed past the edge of the screen.
    @MainActor
    func testStatisticsKeepTheirWidthAfterRotating() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        statsTab.tap()

        let heading = app.staticTexts["STROKES GAINED PUTTING"]
        XCTAssertTrue(heading.waitForExistence(timeout: 10))
        sleep(2)
        let before = heading.frame
        snapshot("1 portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        snapshot("2 landscape")

        XCUIDevice.shared.orientation = .portrait
        sleep(3)
        snapshot("3 portrait again")

        // Every element's frame, so a failure says which one is too wide.
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "hierarchy after rotating back"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)

        let after = heading.frame
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(after.minX, before.minX, accuracy: 1, "before \(before), after \(after), window \(window)")
        XCTAssertEqual(after.width, before.width, accuracy: 1, "before \(before), after \(after), window \(window)")
        XCTAssertLessThanOrEqual(after.maxX, window.maxX + 1, "after \(after), window \(window)")
    }

    /// Nothing in the statistics may be wider than the screen: a vertical
    /// scroll view whose content is wider can be dragged sideways.
    @MainActor
    func testStatisticsFitTheScreen() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        statsTab.tap()
        XCTAssertTrue(app.staticTexts["STROKES GAINED PUTTING"].waitForExistence(timeout: 10))
        sleep(2)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "statistics hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)

        // Everything below the pinned filter header, which has its own
        // sideways-scrolling rows.
        let window = app.windows.firstMatch.frame
        let header = app.buttons["Filter"].frame.maxY + 8
        let overflowing = app.staticTexts.allElementsBoundByIndex
            .filter { $0.frame.minY > header }
            .filter { $0.frame.minX < window.minX - 1 || $0.frame.maxX > window.maxX + 1 }
            .map { "\($0.label.prefix(40)) \($0.frame)" }
        XCTAssertTrue(overflowing.isEmpty, "Outside the screen: \(overflowing)")

        // And a sideways drag moves nothing.
        let heading = app.staticTexts["STROKES GAINED PUTTING"]
        let before = heading.frame
        heading.swipeLeft()
        sleep(1)
        XCTAssertEqual(heading.frame.minX, before.minX, accuracy: 1, "before \(before), after \(heading.frame)")
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
