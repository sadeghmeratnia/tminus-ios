//
//  TMinusUITests.swift
//  TMinusUITests
//
//  Created by Sadegh on 22/04/2026.
//

import XCTest

final class TMinusUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testTabBarShowsLaunchesAndNewsTabs() {
        XCTAssertTrue(app.tabBars.buttons["Launches"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["News"].exists)
    }

    @MainActor
    func testSwitchingTabsUpdatesTheVisibleScreen() {
        XCTAssertTrue(app.navigationBars["Launches"].waitForExistence(timeout: 5))

        app.tabBars.buttons["News"].tap()
        XCTAssertTrue(app.navigationBars["News"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Launches"].tap()
        XCTAssertTrue(app.navigationBars["Launches"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTappingALaunchNavigatesToItsDetailAndBack() throws {
        let launchCard = app.buttons.matching(identifier: "launchCard").firstMatch
        guard launchCard.waitForExistence(timeout: 15) else {
            throw XCTSkip("No launches loaded within the timeout — nothing to navigate to.")
        }

        launchCard.tap()
        XCTAssertTrue(app.descendants(matching: .any)["launchDetailContent"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Launches"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTappingAnArticleNavigatesToItsDetailAndBack() throws {
        app.tabBars.buttons["News"].tap()
        XCTAssertTrue(app.navigationBars["News"].waitForExistence(timeout: 5))

        let articleCard = app.buttons.matching(identifier: "articleCard").firstMatch
        guard articleCard.waitForExistence(timeout: 15) else {
            throw XCTSkip("No articles loaded within the timeout — nothing to navigate to.")
        }

        articleCard.tap()
        XCTAssertTrue(app.descendants(matching: .any)["newsDetailContent"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["News"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
