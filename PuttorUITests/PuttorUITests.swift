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

        XCTAssertTrue(app.staticTexts["SCORE (TO PAR)"].waitForExistence(timeout: 5))
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
        XCTAssertFalse(app.staticTexts["SCORE (TO PAR)"].exists)
        sleep(1)
        snapshot("5 back")
        // Back where the statistics were left, not at the top.
        let arrow = app.buttons["Show how these figures moved"]
        XCTAssertEqual(arrow.frame.midY, arrowBefore.midY, accuracy: 40, "before \(arrowBefore), after \(arrow.frame)")
        XCTAssertTrue(arrow.isHittable)

        // A swipe to the left across the playing stats opens it too.
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: arrow.frame.midX - 60, dy: arrow.frame.midY))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: arrow.frame.midX - 300, dy: arrow.frame.midY)))
        XCTAssertTrue(app.staticTexts["SCORE (TO PAR)"].waitForExistence(timeout: 3))
        snapshot("6 opened with a swipe")
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["SCORE (TO PAR)"].waitForNonExistence(timeout: 3))
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
        tapOnScreen(open, in: app)
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
        tapOnScreen(open, in: app)
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

    /// Short drags until a good piece of the element is on screen — below the
    /// pinned header, clear of the tab bar (in landscape, where the tabs float
    /// up top, of the bottom of the screen) — then a tap in the middle of that
    /// piece. The arrow beside the playing stats is nearly as tall as a
    /// landscape screen, and XCTest will not tap an element whose own middle
    /// is off screen.
    private func tapOnScreen(_ element: XCUIElement, in app: XCUIApplication) {
        let screen = app.windows.firstMatch.frame
        let tabBar = app.tabBars.firstMatch
        let floor = (tabBar.exists && tabBar.frame.minY > 200 ? tabBar.frame.minY : screen.maxY) - 10
        let ceiling = screen.minY + (screen.height > screen.width ? 240 : 80)
        for _ in 0..<14 {
            let frame = element.frame
            if min(frame.maxY, floor) - max(frame.minY, ceiling) >= 60 { break }
            if frame.midY > (ceiling + floor) / 2 {
                drag(app, from: 0.7, to: 0.45)
            } else {
                drag(app, from: 0.45, to: 0.7)
            }
        }
        sleep(1)
        let frame = element.frame
        let middle = (max(frame.minY, ceiling) + min(frame.maxY, floor)) / 2
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: middle)).tap()
    }

    private func drag(_ app: XCUIApplication, from start: CGFloat, to end: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end)))
    }

    /// Screens that draw their own back button still go back with a swipe
    /// from the edge: the custom mode fields, and a round opened from the list.
    @MainActor
    func testSwipeBackWhereScreensHaveTheirOwnBackButton() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen

        // The custom mode fields, from the settings.
        settingsTab.tap()
        let customRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Custom Mode Fields'")).firstMatch
        XCTAssertTrue(customRow.waitForExistence(timeout: 5))
        customRow.tap()
        let customTitle = app.navigationBars.staticTexts["Custom Mode"]
        XCTAssertTrue(customTitle.waitForExistence(timeout: 5))
        sleep(1)
        snapshot("1 custom mode")
        swipeFromLeftEdge(app)
        XCTAssertTrue(customTitle.waitForNonExistence(timeout: 5), "still on the custom mode fields")
        XCTAssertTrue(waitUntilHittable(customRow))
        snapshot("2 settings again")

        // A round opened from the list on the course tab.
        app.tabBars.buttons["Course"].tap()
        let start = app.buttons["Start New Round"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.staticTexts["Demo 1"].firstMatch.tap()
        let summaryPutts = app.staticTexts["Putts"].firstMatch
        XCTAssertTrue(summaryPutts.waitForExistence(timeout: 5))
        sleep(1)
        snapshot("3 round summary")
        swipeFromLeftEdge(app)
        XCTAssertTrue(waitUntilHittable(start), "still on the round")
        snapshot("4 list again")
    }

    /// The charts are arranged by name — one taken out and brought back — and
    /// a round's holes switch to a scorecard.
    @MainActor
    func testChartsArrangeByNameAndHolesSwitchToScore() throws {
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
        tapOnScreen(open, in: app)
        XCTAssertTrue(app.staticTexts["SCORE (TO PAR)"].waitForExistence(timeout: 5))

        app.buttons["Arrange the charts"].tap()
        let done = app.buttons["Done arranging"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        sleep(1)
        snapshot("1 arranging")
        hierarchy(app, "arranging hierarchy")

        // The red minus sits at the row's leading edge and is no button of its
        // own; it opens the row's delete button, named in whatever language
        // the phone speaks.
        let firstRow = app.cells.containing(NSPredicate(format: "label ENDSWITH 'SG PUTTING'")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 3))
        firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 22, dy: 0)).tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label IN {'Delete', 'Löschen', 'Entfernen', 'Eliminar'}")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "the minus opens a delete button")
        confirm.tap()
        // Taken out, it waits under the shown ones, past the bottom of the
        // screen, where the list only lays out its rows once scrolled to.
        let bringBack = app.buttons["Add SG PUTTING"]
        for _ in 0..<6 where !(bringBack.exists && bringBack.isHittable) {
            drag(app, from: 0.75, to: 0.35)
        }
        XCTAssertTrue(bringBack.waitForExistence(timeout: 3), "the taken-out chart offers itself back")
        sleep(1)
        snapshot("2 one taken out")
        bringBack.tap()
        XCTAssertTrue(bringBack.waitForNonExistence(timeout: 3))

        done.tap()
        XCTAssertTrue(app.staticTexts["SCORE (TO PAR)"].waitForExistence(timeout: 3))
        snapshot("3 charts again")

        // A round's holes, as a scorecard.
        app.tabBars.buttons["Course"].tap()
        XCTAssertTrue(app.buttons["Start New Round"].waitForExistence(timeout: 5))
        app.staticTexts["Demo 1"].firstMatch.tap()
        let showScore = app.buttons["Show the score on each hole"]
        XCTAssertTrue(showScore.waitForExistence(timeout: 5))
        for _ in 0..<6 where !showScore.isHittable {
            drag(app, from: 0.7, to: 0.4)
        }
        showScore.tap()
        XCTAssertTrue(app.staticTexts["HOLES · SCORE"].waitForExistence(timeout: 3))
        sleep(1)
        snapshot("4 scorecard")
        app.buttons["What the colours mean"].tap()
        sleep(1)
        snapshot("5 colours")

        // The round settings name the mode above stroke/match play.
        app.tap() // closes the colours
        swipeFromLeftEdge(app)
        let start = app.buttons["Start New Round"]
        XCTAssertTrue(waitUntilHittable(start))
        start.tap()
        let mode = app.staticTexts["MODE"]
        for _ in 0..<6 where !(mode.exists && mode.isHittable) {
            drag(app, from: 0.7, to: 0.45)
        }
        XCTAssertTrue(mode.exists)
        snapshot("6 round settings")
    }

    /// Every point carries its number up to fifteen rounds: all twelve demo
    /// rounds, numbered.
    @MainActor
    func testEvolutionNumbersEveryPointOfTwelveRounds() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        statsTab.tap()

        let allRounds = app.buttons["All Rounds"]
        XCTAssertTrue(allRounds.waitForExistence(timeout: 10))
        // The chip sits past the right edge of its row: drag the row along by
        // position, since XCTest won't say whether an off-screen chip is
        // hittable.
        let screen = app.windows.firstMatch.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<4 where allRounds.frame.maxX > screen.maxX - 8 {
            let row = allRounds.frame.midY
            origin.withOffset(CGVector(dx: screen.width * 0.8, dy: row))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: screen.width * 0.15, dy: row)))
        }
        sleep(1)
        allRounds.tap()
        XCTAssertTrue(app.buttons["ROUNDS (12)"].waitForExistence(timeout: 5))

        let open = app.buttons["Show how these figures moved"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        tapOnScreen(open, in: app)
        XCTAssertTrue(app.staticTexts["SCORE (TO PAR)"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("1 twelve rounds numbered")
        drag(app, from: 0.8, to: 0.35)
        sleep(1)
        snapshot("2 further down")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        snapshot("3 landscape")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
    }

    /// The statistics sections are arranged by name from the three lines in
    /// the header: one taken out is gone from the tab.
    @MainActor
    func testStatisticsSectionsArrangeByName() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        statsTab.tap()
        let rounds = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'ROUNDS ('")).firstMatch
        XCTAssertTrue(rounds.waitForExistence(timeout: 10))
        snapshot("1 statistics")

        app.buttons["Arrange the sections"].tap()
        let done = app.buttons["Done arranging"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        sleep(1)
        snapshot("2 sections by name")

        let row = app.cells.containing(NSPredicate(format: "label ENDSWITH 'ROUNDS'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 22, dy: 0)).tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label IN {'Delete', 'Löschen', 'Entfernen', 'Eliminar'}")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "the minus opens a delete button")
        confirm.tap()
        let bringBack = app.buttons["Add ROUNDS"]
        for _ in 0..<4 where !(bringBack.exists && bringBack.isHittable) {
            drag(app, from: 0.75, to: 0.35)
        }
        XCTAssertTrue(bringBack.waitForExistence(timeout: 3), "the taken-out section offers itself back")
        snapshot("3 rounds taken out")

        done.tap()
        XCTAssertTrue(app.staticTexts["STROKES GAINED PUTTING"].waitForExistence(timeout: 5))
        XCTAssertFalse(rounds.exists)
        sleep(1)
        snapshot("4 statistics without rounds")
    }

    /// The Gate Drill counts the set by side afterwards — made and missed left,
    /// the rest missed right — and the Clock Drill marks each putt left, made
    /// or right; both show the misses by side when they are done.
    @MainActor
    func testDrillsKeepTrackOfTheSideOfEachMiss() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let gamesTab = app.tabBars.buttons["Games"]
        XCTAssertTrue(gamesTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        gamesTab.tap()

        // Gate Drill: on a straight putt, counted after the set.
        let gate = app.staticTexts["Gate Drill"].firstMatch
        XCTAssertTrue(gate.waitForExistence(timeout: 5))
        gate.tap()
        let straight = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Use a straight putt'")).firstMatch
        XCTAssertTrue(straight.waitForExistence(timeout: 5))
        snapshot("1 gate setup")
        app.buttons["Start"].tap()

        let made = app.textFields.element(boundBy: 0)
        let left = app.textFields.element(boundBy: 1)
        XCTAssertTrue(left.waitForExistence(timeout: 5))
        made.tap()
        made.typeText("25")
        let tooMany = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'more than the 20 reps'")).firstMatch
        XCTAssertTrue(tooMany.waitForExistence(timeout: 3), "25 made of 20 is not flagged")
        snapshot("1b too many")
        made.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "12")
        left.tap()
        left.typeText("5")
        let rest = app.staticTexts["Missed right: 3"]
        XCTAssertTrue(rest.waitForExistence(timeout: 3), "the rest of the set counts as missed right")
        rest.tap() // closes the number pad
        sleep(1)
        snapshot("2 gate counted by side")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["MISSES BY SIDE"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("3 gate result")
        app.buttons["Done"].tap()

        // Clock Drill: four positions, two laps, each putt marked by side.
        let clock = app.staticTexts["Clock Drill"].firstMatch
        XCTAssertTrue(clock.waitForExistence(timeout: 5))
        clock.tap()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
        app.buttons["Start"].tap()
        let missedLeft = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Missed left'")).firstMatch
        let holed = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Made'")).firstMatch
        let missedRight = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Missed right'")).firstMatch
        XCTAssertTrue(missedLeft.waitForExistence(timeout: 5))
        snapshot("4 clock buttons")
        for button in [missedLeft, missedLeft, holed, missedRight, missedLeft, holed, missedLeft, missedLeft] {
            button.tap()
        }
        XCTAssertTrue(app.staticTexts["MISSES BY SIDE"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("5 clock result")
    }

    /// A drag up that starts on the playing stats scrolls the tab rather than
    /// being swallowed by the swipe to the evolution, and the dispersion plot
    /// swipes over to the grid of where the misses finished, and back.
    @MainActor
    func testStatisticsScrollOverPlayingStatsAndSwipeToTheMissGrid() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData"]
        app.launch()

        let statsTab = app.tabBars.buttons["Stats"]
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        statsTab.tap()

        let playing = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'PLAYING STATS'")).firstMatch
        let gir = app.staticTexts["GIR"].firstMatch
        XCTAssertTrue(gir.waitForExistence(timeout: 10))
        scrollIntoView(gir, in: app, bottomMargin: 320)
        let before = playing.frame.minY
        let tile = gir.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: tile.midX, dy: tile.midY))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: tile.midX, dy: tile.midY - 240)))
        sleep(1)
        XCTAssertLessThan(playing.frame.minY, before - 100, "dragging up over the playing stats did not scroll")
        XCTAssertFalse(app.staticTexts["SCORE (TO PAR)"].exists, "a drag up opened the evolution")

        let dispersion = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'MISS DISPERSION'")).firstMatch
        XCTAssertTrue(dispersion.waitForExistence(timeout: 5))
        for _ in 0..<14 where dispersion.frame.minY > 260 {
            drag(app, from: 0.75, to: 0.45)
        }
        sleep(1)
        let row = dispersion.frame.maxY + 230
        origin.withOffset(CGVector(dx: 330, dy: row))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 50, dy: row)))
        let justPast = app.staticTexts["Just past"]
        XCTAssertTrue(justPast.waitForExistence(timeout: 3), "no grid after swiping the plot")
        sleep(1)
        snapshot("1 miss grid")
        // Back on the grid's own row: the grid is shorter than the plot, so
        // what stood at the first swipe's height has moved.
        let gridRow = justPast.frame.midY
        origin.withOffset(CGVector(dx: 130, dy: gridRow))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 390, dy: gridRow)))
        XCTAssertTrue(justPast.waitForNonExistence(timeout: 3), "no plot after swiping back")
    }

    /// Three rounds entered the way custom mode asks now: the intention's
    /// switches stand clear of each other, break shading blends on the miss
    /// plot, and the intentions come out in their own section.
    @MainActor
    func testSimulatedRoundsWithSlopeKeypadDialAndIntentions() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorNoRounds", "-PuttorSimulatedRounds"]
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15))
        sleep(3) // past the title screen

        // The intention's parts, each on a row of its own.
        settingsTab.tap()
        let customRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Custom Mode Fields'")).firstMatch
        XCTAssertTrue(customRow.waitForExistence(timeout: 5))
        customRow.tap()
        app.buttons["Edit"].tap()
        // A switch reports itself more than once, so the rows are counted by
        // where the switches sit, and each row must be at least a switch tall.
        func switchRows() -> (centres: [CGFloat], height: CGFloat) {
            let frames = app.switches.allElementsBoundByIndex.map(\.frame)
            var centres: [CGFloat] = []
            for y in frames.map(\.midY).sorted() where centres.last.map({ y - $0 > 4 }) ?? true {
                centres.append(y)
            }
            return (centres, frames.map(\.height).max() ?? 0)
        }
        XCTAssertEqual(switchRows().centres.count, 3)
        let normalPace = app.sliders.firstMatch
        XCTAssertTrue(normalPace.waitForExistence(timeout: 3), "no slider for the normal pace")
        scrollIntoView(normalPace, in: app, bottomMargin: 120)
        snapshot("1 intention switches")
        let rows = switchRows()
        XCTAssertEqual(rows.centres.count, 3)
        for (upper, lower) in zip(rows.centres, rows.centres.dropFirst()) {
            XCTAssertGreaterThanOrEqual(lower - upper, rows.height - 0.5, "switches overlap")
        }

        // Break strength on the miss plot.
        app.tabBars.buttons["Stats"].tap()
        let dispersion = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'MISS DISPERSION'")).firstMatch
        for _ in 0..<20 where !(dispersion.exists && dispersion.frame.minY < 260) {
            drag(app, from: 0.75, to: 0.45)
        }
        sleep(1)
        // A menu picker shows as a pop-up button, its choices as buttons.
        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'No Shading'")).firstMatch.tap()
        let breakStrength = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Break Strength'")).firstMatch
        XCTAssertTrue(breakStrength.waitForExistence(timeout: 3))
        breakStrength.tap()
        sleep(1)
        drag(app, from: 0.6, to: 0.45)
        sleep(1)
        snapshot("2 break shading")

        // The intentions.
        let intention = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'INTENTION – OUTCOME'")).firstMatch
        for _ in 0..<30 where !(intention.exists && intention.frame.minY < 200) {
            drag(app, from: 0.75, to: 0.45)
        }
        XCTAssertTrue(intention.exists, "no intention section")
        sleep(1)
        snapshot("3 intention outcome")
        drag(app, from: 0.8, to: 0.3)
        sleep(1)
        snapshot("4 intention cards")
    }

    /// With no rounds, the list says so and points down at the plus.
    @MainActor
    func testEmptyRoundListPointsToThePlus() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorNoRounds"]
        app.launch()

        XCTAssertTrue(app.staticTexts["No rounds yet."].waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        snapshot("1 empty list")
        XCTAssertTrue(app.buttons["Start New Round"].isHittable)
    }

    /// The round settings take an optional way of reading, and a custom round
    /// set to numbers takes the slope typed on its keypad: side break first,
    /// Enter, then up or down.
    @MainActor
    func testRoundSettingsReadingAndSlopeTypedInNumbers() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-PuttorDemoData", "-PuttorSlopeNumbers"]
        app.launch()

        let start = app.buttons["Start New Round"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        sleep(3) // past the title screen
        start.tap()

        let footFeel = app.buttons["Foot Feel"]
        XCTAssertTrue(footFeel.waitForExistence(timeout: 5))
        scrollIntoView(footFeel, in: app, bottomMargin: 220)
        footFeel.tap()
        XCTAssertTrue(footFeel.isSelected, "foot feel is not picked")

        // A way of reading of one's own, named behind the +.
        app.buttons["Add a way of reading"].tap()
        let name = app.textFields["Your way of reading…"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Plumb bob\n")
        let plumbBob = app.buttons["Plumb bob"]
        XCTAssertTrue(plumbBob.waitForExistence(timeout: 3), "no pill for the new way of reading")
        XCTAssertTrue(plumbBob.isSelected, "the new way of reading is not picked")
        XCTAssertFalse(footFeel.isSelected)
        snapshot("1 own reading picked")

        let custom = app.staticTexts["Custom"].firstMatch
        scrollIntoView(custom, in: app, bottomMargin: 180)
        custom.tap()
        app.buttons["Start Round"].tap()

        let side = app.buttons["SIDE BREAK"]
        let hill = app.buttons["UP / DOWN"]
        XCTAssertTrue(side.waitForExistence(timeout: 10))
        let zero = lowestButton(labelled: "0", in: app)
        scrollIntoView(zero, in: app, bottomMargin: 60)

        lowestButton(labelled: "2", in: app).tap()
        enterKey(in: app).tap()
        lowestButton(labelled: "1", in: app).tap()
        lowestButton(labelled: "±", in: app).tap()
        enterKey(in: app).tap()
        sleep(1)
        snapshot("2 slope typed")

        XCTAssertTrue((side.value as? String ?? "").contains("L→R"), "side break reads \(side.value ?? "nothing")")
        XCTAssertTrue((hill.value as? String ?? "").contains("downhill"), "up or down reads \(hill.value ?? "nothing")")

        // The sign pressed before the number counts too.
        lowestButton(labelled: "±", in: app).tap()
        lowestButton(labelled: "3", in: app).tap()
        enterKey(in: app).tap()
        sleep(1)
        snapshot("3 minus first")
        let sideNow = side.value as? String ?? ""
        XCTAssertTrue(sideNow.contains("-3") && sideNow.contains("R→L"), "side break reads \(sideNow)")
    }

    /// Short drags until the element's bottom sits above the margin.
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication, bottomMargin: CGFloat) {
        let screen = app.windows.firstMatch.frame
        for _ in 0..<14 where element.frame.maxY > screen.maxY - bottomMargin {
            drag(app, from: 0.75, to: 0.45)
        }
        sleep(1)
    }

    /// Of the buttons with this label, the one lowest on the screen: the key
    /// on the keypad rather than a chip higher up.
    private func lowestButton(labelled label: String, in app: XCUIApplication) -> XCUIElement {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex
        return matches.max { $0.frame.minY < $1.frame.minY } ?? app.buttons[label]
    }

    private func enterKey(in app: XCUIApplication) -> XCUIElement {
        let matches = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'enter'")).allElementsBoundByIndex
        return matches.max { $0.frame.minY < $1.frame.minY } ?? app.buttons["Enter"]
    }

    private func swipeFromLeftEdge(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.55))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.55)))
        sleep(1)
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if element.exists && element.isHittable { return true }
            usleep(200_000)
        }
        return false
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
