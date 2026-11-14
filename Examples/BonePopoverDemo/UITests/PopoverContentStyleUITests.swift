import XCTest

final class PopoverContentStyleUITests: XCTestCase {
    @MainActor
    private func openScene(_ index: Int, in app: XCUIApplication) {
        let table = app.tables["demo-list"]
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        let row = app.cells["scene-\(index)"]
        // 顶部控制条与底部结果条压缩了可见区域，多滚动几次保证目标行完整可见。
        for _ in 0..<10 {
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
        app.launchArguments = ["--demo-home", "--demo-scene", "13"]
        app.launch()
        XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
        let content = app.otherElements["popover-content"]
        let title = app.staticTexts["popover-title"]
        let message = app.staticTexts["popover-message"]
        let toggle = app.cells["toggle-content-style"]
        let table = app.tables["drawer-table"]
        let close = app.buttons["drawer-close"]
        let originalHeight = content.frame.height
        for expanded in [true, false] {
            XCTAssertTrue(toggle.isHittable)
            toggle.tap()
            let rowHeight: CGFloat = expanded ? 72 : 55
            let layoutChanged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(toggle.frame.height - rowHeight) <= 1
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [layoutChanged], timeout: 5), .completed)
            XCTAssertEqual(title.frame.minY - content.frame.minY, 10, accuracy: 1)
            XCTAssertEqual(title.frame.midX, content.frame.midX, accuracy: 1)
            XCTAssertEqual(close.frame.minX - content.frame.minX, 16, accuracy: 1)
            XCTAssertEqual(message.frame.minY - title.frame.maxY, (expanded ? 20 : 14) + 10, accuracy: 1)
            XCTAssertEqual(table.frame.minY - message.frame.maxY, expanded ? 24 : 16, accuracy: 1)
            XCTAssertEqual(toggle.frame.height, rowHeight, accuracy: 1)
            XCTAssertEqual(content.frame.maxY - table.frame.maxY, expanded ? 32 : 20, accuracy: 1)
            if expanded { XCTAssertGreaterThan(content.frame.height, originalHeight + 40) }
            else { XCTAssertEqual(content.frame.height, originalHeight, accuracy: 1) }
            XCTAssertEqual(toggle.label, "切换字体与间距")
            XCTAssertTrue(app.otherElements["popover-ready"].exists)
            capture(expanded ? "live-content-style-expanded" : "live-content-style-default")
        }
        close.tap()
    }

    /// 默认底部操作列表：贴底、无遮罩、表格行与左侧箭头关闭，右侧按钮默认隐藏。
    @MainActor
    func testOperationListUsesReaderDefaultSheetLayout() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        openScene(2, in: app)
        let content = app.otherElements["popover-content"].frame
        // 用窗口坐标系判断：app.frame 固定按竖屏返回，横屏或折叠姿态下会与元素坐标不一致。
        let windowFrame = app.windows.firstMatch.frame
        // 宽度填满所在可用区并受 560 点上限约束；Duo 存在系统 division/occlusion 保留区时
        // 只填满所在侧栏、不跨铰链，因此不能断言等于整窗宽度。
        XCTAssertGreaterThan(content.width, min(windowFrame.width, 560) * 0.7)
        XCTAssertLessThanOrEqual(content.width, 561)
        // 贴底：面板底缘位于窗口底部，避让主页指示器安全区。
        XCTAssertLessThanOrEqual(content.maxY, windowFrame.maxY + 1)
        XCTAssertGreaterThan(content.maxY, windowFrame.maxY - 40)
        XCTAssertTrue(app.tables["drawer-table"].isHittable)
        XCTAssertFalse(app.buttons["drawer-confirm"].exists)
        let closeButton = app.buttons["drawer-close"]
        XCTAssertTrue(closeButton.isHittable, "标题左侧应有向下箭头关闭按钮")
        XCTAssertEqual(closeButton.frame.minX - content.minX, 16, accuracy: 1,
                       "关闭按钮左侧间距应与抽屉一致")
        capture("operation-list-reader-default")
        closeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
        XCTAssertTrue(app.cells["scene-2"].waitForExistence(timeout: 5))
    }
}
