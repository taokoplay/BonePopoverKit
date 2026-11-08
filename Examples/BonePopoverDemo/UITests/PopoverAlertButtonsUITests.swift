import XCTest

final class PopoverAlertButtonsUITests: XCTestCase {
    @MainActor
    func testDefaultHorizontalAndVerticalFallbackButtons() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        let table = app.tables["demo-list"]
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        for (scene, horizontal) in [("scene-0", true), ("scene-10", false), ("scene-11", false)] {
            let row = app.cells[scene]
            for _ in 0..<4 {
                if row.isHittable { break }
                table.swipeUp()
            }
            let hittable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in row.exists && row.isHittable }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 5), .completed)
            row.tap()
            XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
            let content = app.otherElements["popover-content"]
            let cancel = app.buttons["取消"]
            let confirm = app.buttons["popover-confirm"]
            XCTAssertTrue(cancel.isHittable)
            XCTAssertTrue(confirm.isHittable)
            XCTAssertGreaterThanOrEqual(confirm.frame.height, 44)
            XCTAssertEqual(cancel.frame.minX - content.frame.minX, 24, accuracy: 1)
            XCTAssertEqual(content.frame.maxX - confirm.frame.maxX, 24, accuracy: 1)
            XCTAssertEqual(cancel.frame.width, confirm.frame.width, accuracy: 1)
            if horizontal {
                XCTAssertEqual(cancel.frame.minY, confirm.frame.minY, accuracy: 1)
                XCTAssertEqual(confirm.frame.minX - cancel.frame.maxX, 12, accuracy: 1)
            } else {
                XCTAssertEqual(cancel.frame.minX, confirm.frame.minX, accuracy: 1)
                XCTAssertEqual(cancel.frame.minY - confirm.frame.maxY, 12, accuracy: 1)
            }
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "alert-buttons-\(scene)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if horizontal { confirm.tap() }
            else { cancel.tap() }
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !app.otherElements["popover-ready"].exists
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        }
    }
}
