import XCTest

final class PopoverInteractionUITests: XCTestCase {
    @MainActor
    private func playground() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        app.buttons["interaction-demo"].tap()
        XCTAssertTrue(app.cells["interaction-center"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func select(_ name: String, in app: XCUIApplication) {
        app.buttons["interaction-presets"].tap()
        app.buttons[name].tap()
    }

    @MainActor
    private func showCenter(in app: XCUIApplication) {
        app.cells["interaction-center"].tap()
        XCTAssertTrue(app.otherElements["interaction-ready"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func waitForDismissal(in app: XCUIApplication) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !app.otherElements["interaction-ready"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor
    private func dragTitle(in app: XCUIApplication, direction: String, distance: CGFloat? = nil) {
        let title = app.staticTexts["interaction-title"]
        let startPoint = CGPoint(x: title.frame.midX, y: title.frame.midY)
        var endPoint = startPoint
        switch direction {
        case "left": endPoint.x = distance.map { startPoint.x - $0 } ?? app.frame.minX + 10
        case "right": endPoint.x = distance.map { startPoint.x + $0 } ?? app.frame.maxX - 10
        case "up": endPoint.y = distance.map { startPoint.y - $0 } ?? app.frame.minY + 70
        default: endPoint.y = distance.map { startPoint.y + $0 } ?? app.frame.maxY - 20
        }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: startPoint.x, dy: startPoint.y))
        let end = origin.withOffset(CGVector(dx: endPoint.x, dy: endPoint.y))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    @MainActor
    func testHiddenBackdropOutsideTapAndPassthroughCombinations() {
        let app = playground()
        let counter = app.cells["interaction-counter"]
        let outside = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: counter.frame.midX, dy: counter.frame.midY))
        select("透明背景外部关闭", in: app)
        showCenter(in: app)
        outside.tap()
        waitForDismissal(in: app)
        XCTAssertTrue(counter.staticTexts["底层点击次数：0"].exists, "Blocking outside tap must not activate the underlying row")

        select("拦截外部点击", in: app)
        showCenter(in: app)
        outside.tap()
        XCTAssertTrue(app.otherElements["interaction-ready"].exists)
        app.buttons["取消"].tap()
        waitForDismissal(in: app)

        select("穿透不关闭", in: app)
        showCenter(in: app)
        counter.tap()
        XCTAssertTrue(counter.staticTexts["底层点击次数：1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["interaction-ready"].exists)
        app.buttons["取消"].tap()
        waitForDismissal(in: app)

        select("穿透并关闭", in: app)
        showCenter(in: app)
        counter.tap()
        waitForDismissal(in: app)
        XCTAssertTrue(counter.staticTexts["底层点击次数：2"].waitForExistence(timeout: 5),
                      "One tap must both reach the underlying row and dismiss the popover")
    }

    @MainActor
    func testCenterDismissesWithActualDragsInAllFourDirections() {
        let app = playground()
        select("四向滑动", in: app)
        for direction in ["left", "right", "up", "down"] {
            showCenter(in: app)
            dragTitle(in: app, direction: direction)
            waitForDismissal(in: app)
        }
    }

    @MainActor
    func testDisallowedDirectionAndCustomThresholdKeepPopoverOpen() {
        let app = playground()
        select("仅左滑", in: app)
        showCenter(in: app)
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "restricted-direction-before"
        before.lifetime = .keepAlways
        add(before)
        dragTitle(in: app, direction: "right")
        XCTAssertTrue(app.otherElements["interaction-ready"].exists, app.debugDescription)
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "restricted-direction-after"
        after.lifetime = .keepAlways
        add(after)
        dragTitle(in: app, direction: "left")
        waitForDismissal(in: app)

        select("高阈值滑动", in: app)
        showCenter(in: app)
        dragTitle(in: app, direction: "down", distance: 30)
        XCTAssertTrue(app.otherElements["interaction-ready"].exists)
        dragTitle(in: app, direction: "down")
        waitForDismissal(in: app)
    }
}
