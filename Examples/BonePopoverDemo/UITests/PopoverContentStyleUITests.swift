import XCTest

final class PopoverContentStyleUITests: XCTestCase {
    @MainActor
    private func openScene(_ index: Int, in app: XCUIApplication) {
        let table = app.tables["demo-list"]
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        let row = app.cells["scene-\(index)"]
        for _ in 0..<5 {
            if row.isHittable { break }
            table.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCustomAlertTypographyAndSpacing() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        openScene(12, in: app)
        let content = app.otherElements["popover-content"].frame
        let title = app.staticTexts["popover-title"].frame
        let message = app.staticTexts["popover-message"].frame
        let confirm = app.buttons["popover-confirm"]
        let cancel = app.buttons["popover-cancel"]
        XCTAssertEqual(title.minY - content.minY, 20, accuracy: 1)
        XCTAssertEqual(title.minX - content.minX, 28, accuracy: 1)
        XCTAssertEqual(content.maxX - title.maxX, 28, accuracy: 1)
        XCTAssertEqual(message.minY - title.maxY, 10, accuracy: 1)
        XCTAssertEqual(confirm.frame.minY - message.maxY, 24, accuracy: 1)
        XCTAssertEqual(cancel.frame.minY - confirm.frame.maxY, 18, accuracy: 1)
        XCTAssertEqual(content.maxY - cancel.frame.maxY, 28, accuracy: 1)
        XCTAssertTrue(confirm.isHittable)
        XCTAssertTrue(cancel.isHittable)
        capture("custom-alert-content-style")
        cancel.tap()
        XCTAssertTrue(app.cells["scene-12"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLiveStyleChangesAndRestoresTheActionListLayout() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        openScene(13, in: app)
        let content = app.otherElements["popover-content"]
        let title = app.staticTexts["popover-title"]
        let message = app.staticTexts["popover-message"]
        let toggle = app.buttons["toggle-content-style"]
        let cancel = app.buttons["popover-cancel"]
        let originalHeight = content.frame.height
        for expanded in [true, false] {
            XCTAssertTrue(toggle.isHittable)
            toggle.tap()
            let padding: CGFloat = expanded ? 32 : 24
            let layoutChanged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(title.frame.minY - content.frame.minY - padding) <= 1
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [layoutChanged], timeout: 5), .completed)
            XCTAssertEqual(title.frame.minX - content.frame.minX, padding, accuracy: 1)
            XCTAssertEqual(content.frame.maxX - title.frame.maxX, padding, accuracy: 1)
            XCTAssertEqual(message.frame.minY - title.frame.maxY, expanded ? 20 : 14, accuracy: 1)
            XCTAssertEqual(toggle.frame.minY - message.frame.maxY, expanded ? 28 : 14, accuracy: 1)
            XCTAssertEqual(cancel.frame.minY - toggle.frame.maxY, expanded ? 20 : 12, accuracy: 1)
            XCTAssertEqual(content.frame.maxY - cancel.frame.maxY, padding, accuracy: 1)
            if expanded { XCTAssertGreaterThan(content.frame.height, originalHeight + 40) }
            else { XCTAssertEqual(content.frame.height, originalHeight, accuracy: 1) }
            XCTAssertEqual(toggle.label, "切换字体与间距")
            capture(expanded ? "live-content-style-expanded" : "live-content-style-default")
        }
        cancel.tap()
    }
}
