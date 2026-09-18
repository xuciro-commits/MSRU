//
//  MSRUUITests.swift
//  MSRUUITests
//

import XCTest


final class MSRUUITests:
    XCTestCase {

    override func setUpWithError()
        throws {

        continueAfterFailure =
            false
    }


    @MainActor
    func testApplicationLaunches()
        throws {

        let app =
            XCUIApplication()


        /*
         UI Test 不恢复上一次窗口状态。

         避免测试结果受到开发时
         上一次 App session 的影响。
         */

        app.launchArguments += [
            "-ApplePersistenceIgnoreState",
            "YES"
        ]


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
            "MSRU should reach the foreground after launch."
        )
    }
}
