import XCTest

final class PopoverDemoUITests: XCTestCase {
    @MainActor
    func testConfirmationInputAndLiveStyleSwitch() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        app.cells["scene-0"].tap()
        XCTAssertTrue(app.buttons["确认"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
        capture("center-dialog")
        app.buttons["确认"].tap()
        waitUntilHittable(app.cells["scene-1"])
        app.cells["scene-1"].tap()
        let input = app.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Bone SDK")
        XCTAssertTrue(app.buttons["确认"].isHittable)
        capture("keyboard-input")
        app.buttons["确认"].tap()
        waitUntilHittable(app.cells["scene-2"])
        app.cells["scene-2"].tap()
        XCTAssertTrue(app.buttons["切换风格"].waitForExistence(timeout: 5))
        for _ in 0..<4 { app.buttons["切换风格"].tap() }
        XCTAssertTrue(app.buttons["归档项目"].isHittable)
        capture("action-sheet-brand-glass")
        app.buttons["取消"].tap()
        XCTAssertTrue(app.cells["scene-0"].isHittable)
    }

    @MainActor
    func testInjectedFoldRegionsKeepActionsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        let list = app.tables["demo-list"]
        if !app.cells["scene-6"].isHittable { list.swipeUp() }
        app.cells["scene-6"].tap()
        let confirm = app.buttons["确认"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isHittable)
        XCTAssertTrue(confirm.frame.maxX <= app.frame.midX - 12 || confirm.frame.minX >= app.frame.midX + 12,
                      "The action must remain entirely on one side of the fold.")
        capture("injected-book-fold")
        app.buttons["取消"].tap()
        if !app.cells["scene-7"].isHittable { list.swipeUp() }
        app.cells["scene-7"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isHittable)
        XCTAssertTrue(confirm.frame.maxY <= app.frame.midY - 12 || confirm.frame.minY >= app.frame.midY + 12,
                      "The action must remain entirely above or below the fold.")
        capture("injected-tabletop-fold")
        app.buttons["取消"].tap()
    }

    @MainActor
    func testTitleAlignmentAndFullWidthButtons() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        for (name, suffix) in [("左对齐", "left"), ("居中", "center"), ("右对齐", "right")] {
            app.buttons["title-alignment"].tap()
            app.buttons[name].tap()
            app.cells["scene-0"].tap()
            XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
            let content = app.otherElements["popover-content"]
            let title = app.staticTexts["popover-title"]
            let confirm = app.buttons["popover-confirm"]
            let cancel = app.buttons["取消"]
            XCTAssertEqual(title.frame.minY - content.frame.minY, 24, accuracy: 1)
            XCTAssertEqual(cancel.frame.minX - content.frame.minX, 24, accuracy: 1)
            XCTAssertEqual(content.frame.maxX - confirm.frame.maxX, 24, accuracy: 1)
            XCTAssertEqual(confirm.frame.minY, cancel.frame.minY, accuracy: 1)
            XCTAssertEqual(confirm.frame.width, cancel.frame.width, accuracy: 1)
            XCTAssertEqual(confirm.frame.minX - cancel.frame.maxX, 12, accuracy: 1)
            XCTAssertTrue(confirm.isHittable)
            capture("title-\(suffix)")
            app.buttons["取消"].tap()
            waitUntilHittable(app.buttons["title-alignment"])
        }
        app.cells["scene-2"].tap()
        XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
        let content = app.otherElements["popover-content"]
        let title = app.staticTexts["popover-title"]
        let action = app.buttons["归档项目"]
        XCTAssertEqual(title.frame.minY - content.frame.minY, 24, accuracy: 1)
        XCTAssertEqual(action.frame.minX - content.frame.minX, 24, accuracy: 1)
        XCTAssertEqual(content.frame.maxX - action.frame.maxX, 24, accuracy: 1)
        capture("sheet-title-right")
        app.buttons["取消"].tap()
    }

    @MainActor
    func testAlertOuterMarginsAndMaximumSize() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        XCTAssertTrue(app.tables["demo-list"].waitForExistence(timeout: 10))
        waitUntilHittable(app.cells["scene-0"])
        let cases: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("scene-0", 32, 420, 600),
            ("scene-8", 48, 360, 460),
            ("scene-9", 32, 420, 600)
        ]
        for (scene, margin, maximumWidth, maximumHeight) in cases {
            let row = app.cells[scene]
            if !row.isHittable { app.tables["demo-list"].swipeUp() }
            waitUntilHittable(row)
            row.tap()
            XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
            let viewport = app.scrollViews.firstMatch
            XCTAssertTrue(viewport.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(viewport.frame.minX, app.frame.minX + margin - 1)
            XCTAssertLessThanOrEqual(viewport.frame.maxX, app.frame.maxX - margin + 1)
            XCTAssertLessThanOrEqual(viewport.frame.width, maximumWidth + 1)
            XCTAssertLessThanOrEqual(viewport.frame.height, maximumHeight + 1)
            capture("alert-sizing-\(scene)")
            for _ in 0..<12 {
                if app.buttons["取消"].isHittable { break }
                viewport.swipeUp()
            }
            XCTAssertTrue(app.buttons["取消"].isHittable)
            app.buttons["取消"].tap()
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !app.otherElements["popover-ready"].exists
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        }
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            element.exists && element.isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }

    /// 抽屉场景：分组行可见，点击行回传结果并关闭；遮罩控制存在。
    @MainActor
    func testDrawerSceneSelectsRowAndReportsResult() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-home"]
        app.launch()
        XCTAssertTrue(app.segmentedControls["backdrop-control"].waitForExistence(timeout: 10))
        let table = app.tables["demo-list"]
        let row = app.cells["scene-18"]
        for _ in 0..<3 where !row.isHittable { table.swipeUp() }
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.otherElements["popover-ready"].waitForExistence(timeout: 5))
        // 抽屉改用 UITableView 后，行是 cell；先按 cell 找，兼容早期按 button 暴露的版本。
        let option = app.cells["drawer-row-0-1"].exists
            ? app.cells["drawer-row-0-1"] : app.buttons["drawer-row-0-1"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        capture("drawer-sheet")
        option.tap()
        app.buttons["drawer-confirm"].tap()
        XCTAssertTrue(app.staticTexts["demo-result"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["demo-result"].label, "抽屉提交：仿真")
        XCTAssertTrue(app.cells["scene-18"].waitForExistence(timeout: 5))
    }

    /// 三个抽屉变体：单组单选、单选+拖动、固定高度滚动列表。
    /// 用 `--demo-scene` 直接打开，避免在分组列表里滚动定位带来的坐标误差。
    @MainActor
    func testDrawerVariantsOpenAndScroll() {
        let app = XCUIApplication()

        func open(scene: Int, title: String) {
            app.terminate()
            app.launchArguments = ["--demo-home", "--demo-scene", String(scene)]
            app.launch()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10),
                          "场景 \(scene) 没有打开：\(title)")
            XCTAssertTrue(app.tables["drawer-table"].waitForExistence(timeout: 5))
        }

        // 20：只有一组单选
        open(scene: 20, title: "翻页方式")
        XCTAssertTrue(app.cells["drawer-row-0-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.cells["drawer-row-0-2"].exists)
        XCTAssertFalse(app.cells["drawer-row-1-0"].exists, "单组单选不应有第二个分区")
        capture("drawer-single-section")

        // 21：单选 + 拖动
        open(scene: 21, title: "翻页与排序")
        XCTAssertTrue(app.cells["drawer-row-0-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.cells["drawer-row-1-2"].exists, "拖动分区应有 3 行")
        capture("drawer-drag-section")

        // 22：固定高度 + 内部滚动
        open(scene: 22, title: "长列表")
        XCTAssertTrue(app.cells["drawer-row-0-0"].waitForExistence(timeout: 5))
        let last = app.cells["drawer-row-0-13"]
        XCTAssertFalse(last.isHittable, "第 14 行应在可视区外")
        var swipes = 0
        while !last.isHittable && swipes < 6 {
            app.tables["drawer-table"].swipeUp()
            swipes += 1
        }
        XCTAssertTrue(last.isHittable, "滚动后应能看到最后一行（swipes=\(swipes)）")
        capture("drawer-scrolling-list")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
