import XCTest

final class PopoverToastUITests: XCTestCase {
    @MainActor
    private func openScene(_ index: Int, in app: XCUIApplication) {
        let table = app.tables["demo-list"]
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        let row = app.cells["scene-\(index)"]
        for _ in 0..<6 {
            if row.isHittable { break }
            table.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["toast-message"].exists)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitForDismissal(in app: XCUIApplication) {
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                               object: app.otherElements["popover-ready"])
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 15), .completed)
        XCTAssertFalse(app.staticTexts["toast-message"].exists)
    }

    @MainActor
    func testTopAndBottomBarsAllowUnderlyingActionsAndAutoDismiss() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launchEnvironment["BONE_TOAST_DEMO_DURATION"] = "10"
        app.launch()
        openScene(15, in: app)
        let top = app.otherElements["popover-content"].frame
        XCTAssertLessThan(top.maxY, app.frame.midY)
        XCTAssertGreaterThan(top.width, top.height * 3)
        capture("toast-top-bar")
        // 顶部 Toast 仍在显示时，真实点击底层另一行，验证触摸穿透。
        XCTAssertTrue(app.otherElements["popover-ready"].exists)
        openScene(16, in: app)
        let bottom = app.otherElements["popover-content"].frame
        XCTAssertGreaterThan(bottom.minY, app.frame.midY)
        XCTAssertGreaterThan(bottom.width, bottom.height * 3)
        capture("toast-bottom-bar")
        waitForDismissal(in: app)
        XCTAssertTrue(app.cells["scene-17"].isHittable)
    }

    @MainActor
    func testCenterSquareAutoDismisses() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["BONE_TOAST_DEMO_DURATION"] = "10"
        app.launchArguments = ["--demo-home"]
        app.launch()
        openScene(17, in: app)
        let content = app.otherElements["popover-content"].frame
        let message = app.staticTexts["toast-message"].frame
        XCTAssertEqual(content.width, content.height, accuracy: 1)
        XCTAssertGreaterThanOrEqual(content.width, 160)
        XCTAssertLessThanOrEqual(content.width, 280)
        XCTAssertEqual(message.midX, content.midX, accuracy: 1)
        XCTAssertTrue(content.contains(message))
        capture("toast-center-square")
        waitForDismissal(in: app)
    }

    @MainActor
    func testTypesAndDurationCanChangeWhileVisible() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launchEnvironment["BONE_TOAST_DEMO_DURATION"] = "10"
        app.launch()
        openScene(17, in: app)
        let message = app.staticTexts["toast-message"]
        XCTAssertEqual(message.value as? String, "成功")
        app.buttons["toast-options"].tap()
        app.buttons["自动消失时间"].tap()
        app.buttons["持续显示"].tap()
        for type in ["失败", "提示", "加载中", "成功"] {
            app.buttons["toast-options"].tap()
            app.buttons[type].tap()
            let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", type), object: message)
            XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)
            XCTAssertTrue(app.otherElements["popover-ready"].exists)
            capture("toast-type-\(type)")
        }
        app.buttons["toast-options"].tap()
        app.buttons["自动消失时间"].tap()
        app.buttons["1 秒"].tap()
        waitForDismissal(in: app)
    }
}
