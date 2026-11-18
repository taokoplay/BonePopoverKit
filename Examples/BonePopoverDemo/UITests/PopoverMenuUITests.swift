import XCTest

final class PopoverMenuUITests: XCTestCase {
    @MainActor
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home", "--demo-scene", "23"]
        app.launch()
        // 页面完成 push 后再点按，避免冷启动时在导航转场中命中旧位置。
        XCTAssertTrue(app.otherElements["menu-screen-ready"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["menu-anchor-top"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func open(_ identifier: String, in app: XCUIApplication) -> CGRect {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.isHittable)
        let frame = button.frame
        button.tap()
        XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tables["menu-table"].exists)
        return frame
    }

    @MainActor
    private func waitUntil(_ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testBelowAndAbovePlacementAndOutsideTapDoesNotActivateUnderlyingButton() {
        let app = launch()
        let bottomButton = app.buttons["menu-anchor-bottom"]
        let bottomFrame = bottomButton.frame
        let topFrame = open("menu-anchor-top", in: app)
        var content = app.otherElements["popover-content"].frame
        XCTAssertEqual(content.minY - topFrame.maxY, 8, accuracy: 1)
        XCTAssertEqual(content.minX, topFrame.minX, accuracy: 1)
        XCTAssertEqual(content.width, 260, accuracy: 1)
        XCTAssertTrue(app.cells["menu-favorite"].isHittable)
        XCTAssertTrue(app.cells["menu-delete"].isHittable)
        capture("menu-below-default")

        // 点在底层另一个按钮上，只关闭菜单，不能同时触发底层按钮。
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: bottomFrame.midX, dy: bottomFrame.midY)).tap()
        waitUntil { !app.otherElements["popover-ready"].exists }
        XCTAssertTrue(bottomButton.isHittable)
        let anchor = open("menu-anchor-bottom", in: app)
        content = app.otherElements["popover-content"].frame
        XCTAssertEqual(anchor.minY - content.maxY, 8, accuracy: 1)
        XCTAssertLessThanOrEqual(content.maxX, app.windows.firstMatch.frame.maxX - 11)
        XCTAssertGreaterThanOrEqual(content.minX, 12)
        capture("menu-above-bottom-edge")
        app.cells["menu-share"].tap()
        waitUntil { !app.otherElements["popover-ready"].exists }
        XCTAssertEqual(app.staticTexts["menu-demo-result"].label, "已选择：分享")
    }

    @MainActor
    func testSelectionAndMaterialUpdateStayOpenAndDisabledRowHasNoEffect() {
        let app = launch()
        let outside = app.buttons["menu-anchor-bottom"].frame
        _ = open("menu-anchor-top", in: app)
        let favorite = app.cells["menu-favorite"]
        XCTAssertEqual(favorite.value as? String, "已选中")
        let disabled = app.cells["menu-disabled"]
        XCTAssertFalse(disabled.isEnabled)
        disabled.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.otherElements["popover-ready"].exists)
        XCTAssertEqual(favorite.value as? String, "已选中")
        favorite.tap()
        waitUntil { (favorite.value as? String) != "已选中" }
        XCTAssertTrue(app.otherElements["popover-ready"].exists)
        app.cells["menu-switch-material"].tap()
        XCTAssertTrue(app.otherElements["popover-ready"].exists)
        capture("menu-solid-unselected")
        favorite.tap()
        waitUntil { (favorite.value as? String) == "已选中" }
        app.cells["menu-switch-material"].tap()
        capture("menu-frosted-selected")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: outside.midX, dy: outside.midY)).tap()
        waitUntil { !app.otherElements["popover-ready"].exists }
        XCTAssertEqual(app.staticTexts["menu-demo-result"].label, "已收藏")
    }

    @MainActor
    func testNormalAndDestructiveRowsDismissAndReportTheirCallbacks() {
        let app = launch()
        for (identifier, result) in [("menu-share", "已选择：分享"), ("menu-delete", "演示：已删除")] {
            _ = open("menu-anchor-top", in: app)
            app.cells[identifier].tap()
            waitUntil {
                !app.otherElements["popover-ready"].exists
                    && app.staticTexts["menu-demo-result"].label == result
            }
        }
    }

    @MainActor
    func testLongMenuScrollsToAndInvokesFinalItem() {
        let app = launch()
        _ = open("menu-long", in: app)
        let table = app.tables["menu-table"]
        let last = app.cells["menu-long-24"]
        XCTAssertFalse(last.isHittable)
        for _ in 0..<14 {
            if last.isHittable && last.frame.maxY <= table.frame.maxY + 1 { break }
            table.swipeUp()
        }
        XCTAssertTrue(last.isHittable)
        XCTAssertLessThanOrEqual(last.frame.maxY, table.frame.maxY + 1)
        capture("menu-long-last-item")
        last.tap()
        waitUntil { !app.otherElements["popover-ready"].exists }
        XCTAssertEqual(app.staticTexts["menu-demo-result"].label, "已选择：菜单项目 24")
    }
}
