//
//  MSRUUITests.swift
//  MSRUUITests
//

import XCTest


final class MSRUUITests:
    XCTestCase {

    #if os(macOS)
    @MainActor
    func testQuitRestoresOpenWindowsAndExcludesExplicitlyClosedWindow() {
        let app = XCUIApplication()
        app.launchEnvironment["MSRU_UI_TEST_SUITE"] = "MSRU.UITests." + UUID().uuidString
        defer { app.terminate() }
        app.launch()
        let scenes = app.windows.matching(NSPredicate(format: "identifier BEGINSWITH %@", "scene."))
        XCTAssertTrue(scenes.firstMatch.waitForExistence(timeout: 10))
        let firstID = scenes.firstMatch.identifier
        app.typeKey("n", modifierFlags: .command)
        waitForCount(2, in: scenes)
        let secondID = scenes.allElementsBoundByIndex.map(\.identifier).first { $0 != firstID }!
        app.typeKey("w", modifierFlags: .command)
        waitForCount(1, in: scenes)
        XCTAssertEqual(scenes.firstMatch.identifier, firstID)
        app.typeKey("n", modifierFlags: .command)
        waitForCount(2, in: scenes)
        let survivingIDs = Set(scenes.allElementsBoundByIndex.map(\.identifier))
        XCTAssertFalse(survivingIDs.contains(secondID))
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        waitForCount(2, in: scenes)
        XCTAssertEqual(Set(scenes.allElementsBoundByIndex.map(\.identifier)), survivingIDs)
    }

    @MainActor
    private func waitForCount(_ expected: Int, in query: XCUIElementQuery) {
        let predicate = NSPredicate { _, _ in query.count == expected }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }
    #endif

    override func setUpWithError()
        throws {

        continueAfterFailure =
            false
    }


    @MainActor
    func testApplicationCanBecomeForeground()
        throws {

        let app =
            XCUIApplication()


        #if os(macOS)
        app.launchEnvironment["MSRU_UI_TEST_SUITE"] = "MSRU.UITests." + UUID().uuidString
        #endif
        defer { app.terminate() }
        app.launch()

        let becameActive =
            app.wait(
                for:
                    .runningForeground,
                timeout:
                    10
            )


        XCTAssertTrue(
            becameActive,
            "MSRU should be able to enter the foreground."
        )
    }
}
