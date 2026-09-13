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
        // One snapshot of the whole tree: resolving the texts one by one
        // fails as soon as any of them changes in the meantime.
        func texts(in element: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
            (element.elementType == .staticText ? [element] : []) + element.children.flatMap(texts)
        }
        let overflowing = try texts(in: app.snapshot())
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

    /// The arrow beside the playing stats slides their evolution in, and a
    /// swipe to the right slides the statistics back.
    @MainActor
    func testPlayingStatsEvolutionSlidesInAndBack() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        statsTab.tap()

        let open = app.buttons["Show how these figures moved"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        // Short drags, until the arrow sits clear of the tab bar: the
        // statistics must be scrolled for coming back to mean anything.
        let tabBarTop = app.tabBars.firstMatch.frame.minY
        var drags = 0
        while open.frame.midY > tabBarTop - 60 && drags < 12 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
            drags += 1
        }
        sleep(1)
        let arrowBefore = open.frame
        XCTAssertGreaterThan(drags, 0)
        snapshot("1 statistics with arrow")
        open.tap()

        XCTAssertTrue(app.staticTexts["SCORE (OVER PAR)"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("2 evolution")
        app.swipeUp()
        sleep(1)
        snapshot("3 evolution scrolled")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(4)
        snapshot("4 evolution landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(4)
        snapshot("4b evolution portrait again")

        XCTAssertTrue(app.buttons["Back to the statistics"].exists)
        app.swipeRight()
        sleep(1)
        // Marked with an asterisk when some rounds carry no score.
        let playingStats = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'PLAYING STATS'")).firstMatch
        XCTAssertTrue(playingStats.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["SCORE (OVER PAR)"].exists)
        sleep(1)
        snapshot("5 back")
        // Back where the statistics were left, not at the top.
        let arrow = app.buttons["Show how these figures moved"]
        XCTAssertEqual(arrow.frame.midY, arrowBefore.midY, accuracy: 40, "before \(arrowBefore), after \(arrow.frame)")
        XCTAssertTrue(arrow.isHittable)
    }

    /// Compare in landscape splits the statistics into two panes; turning
    /// back to portrait must leave the single pane whole again.
    @MainActor
    func testCompareInLandscapeAndBack() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        statsTab.tap()
        XCTAssertTrue(app.staticTexts["STROKES GAINED PUTTING"].waitForExistence(timeout: 10))

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        snapshot("1 landscape")

        let compare = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'compare'")).firstMatch
        XCTAssertTrue(compare.waitForExistence(timeout: 5))
        compare.tap()
        sleep(3)
        snapshot("2 compare")
        hierarchy(app, "compare hierarchy")

        // Two panes, each inside the screen, and the title row still there.
        let headings = app.staticTexts.matching(NSPredicate(format: "label == 'STROKES GAINED PUTTING'"))
        XCTAssertEqual(headings.count, 2)
        let screen = app.windows.firstMatch.frame
        for pane in headings.allElementsBoundByIndex {
            XCTAssertGreaterThanOrEqual(pane.frame.minX, screen.minX - 1, "heading \(pane.frame), screen \(screen)")
            XCTAssertLessThanOrEqual(pane.frame.maxX, screen.maxX + 1, "heading \(pane.frame), screen \(screen)")
        }
        XCTAssertTrue(compare.isHittable, "compare at \(compare.frame)")

        XCUIDevice.shared.orientation = .portrait
        sleep(3)
        snapshot("3 portrait again")
        hierarchy(app, "portrait hierarchy")

        let heading = app.staticTexts["STROKES GAINED PUTTING"]
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(heading.exists)
        XCTAssertLessThanOrEqual(heading.frame.maxX, window.maxX + 1, "heading \(heading.frame), window \(window)")

        // Turned again, compare starts closed.
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        snapshot("4 landscape again")
        XCTAssertEqual(headings.count, 1)
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
    }

    /// Turning the screen while the evolution is open and going back in the
    /// new orientation must leave the app answering, both ways round.
    @MainActor
    func testEvolutionTurnThenGoBack() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        statsTab.tap()

        let open = app.buttons["Show how these figures moved"]
        let back = app.buttons["Back to the statistics"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        bringIntoReach(open, in: app)
        open.tap()
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        snapshot("1 evolution portrait")

        // Portrait to landscape, then back while turned.
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        snapshot("2 evolution landscape")
        var started = Date()
        back.tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertLessThan(Date().timeIntervalSince(started), 8, "going back in landscape took too long")
        sleep(2)
        snapshot("3 statistics landscape")
        hierarchy(app, "statistics landscape")

        // Landscape to portrait, then back with a swipe.
        bringIntoReach(open, in: app)
        open.tap()
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        sleep(1)
        snapshot("4 evolution opened in landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(3)
        snapshot("5 evolution portrait again")
        started = Date()
        app.swipeRight()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertLessThan(Date().timeIntervalSince(started), 8, "going back in portrait took too long")
        sleep(2)
        snapshot("6 statistics portrait")

        // Still answering: the tabs switch.
        app.tabBars.buttons["Coach"].tap()
        XCTAssertTrue(app.tabBars.buttons["Stats"].waitForExistence(timeout: 5))
        snapshot("7 coach")
    }

    /// Short drags until the element sits clear of the tab bar — or, in
    /// landscape, where the tabs float up top, of the bottom of the screen.
    private func bringIntoReach(_ element: XCUIElement, in app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        let floor = tabBar.exists && tabBar.frame.minY > 200 ? tabBar.frame.minY : app.windows.firstMatch.frame.maxY
        var drags = 0
        while (element.frame.midY > floor - 60 || !element.isHittable) && drags < 14 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            drags += 1
        }
        sleep(1)
    }

    private func hierarchy(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
