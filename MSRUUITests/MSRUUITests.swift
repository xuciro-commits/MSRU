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
    func testApplicationCanBecomeForeground()
        throws {

        let app =
            XCUIApplication()


        /*
         Smoke test 只验证：

         MSRU 可以进入前台运行状态。

         不测试坐标，
         不点击 UI，
         不依赖具体页面结构。

         activate() 允许测试附着到
         已经运行的 MSRU。

         如果 App 尚未运行，
         XCTest 会启动它。
         */

        app.activate()


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
