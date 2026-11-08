import XCTest

final class PopoverWindowUITests: XCTestCase {
    @MainActor
    private func launchDemo() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--window-demo"]
        app.launch()
        waitForHittable(mainScreen(in: app).buttons["window-counter"])
        return app
    }

    @MainActor
    private func mainScreen(in app: XCUIApplication) -> XCUIElement {
        app.otherElements["window-main-screen"].firstMatch
    }

    @MainActor
    private func openSecondary(in app: XCUIApplication) -> XCUIElement {
        tapRow("open-secondary", on: mainScreen(in: app))
        let screen = app.otherElements["window-secondary-screen"].firstMatch
        waitForHittable(screen.buttons["window-counter"])
        return screen
    }

    @MainActor @discardableResult
    private func tapRow(_ id: String, on screen: XCUIElement) -> String? {
        let row = screen.cells["window-\(id)"]
        let table = screen.tables["window-demo-list"]
        // 按实际位置小步滚动，避免完整 swipe 越过目标行后一直向同一方向查找。
        for _ in 0..<20 {
            if row.exists && row.isHittable { break }
            let targetIsAbove = row.exists && row.frame.maxY <= table.frame.minY + 8
            let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: targetIsAbove ? 0.3 : 0.75))
            let end = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: targetIsAbove ? 0.65 : 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        waitForHittable(row)
        let value = row.value as? String
        row.tap()
        return value
    }

    @MainActor
    private func show(_ kind: String, on screen: XCUIElement, in app: XCUIApplication) {
        tapRow(kind, on: screen)
        waitForReady(kind, in: app)
    }

    @MainActor
    private func waitForReady(_ kind: String, in app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["window-popup-\(kind)-ready"].waitForExistence(timeout: 8))
        let close = app.buttons["window-popup-\(kind)-close"]
        if kind != "input" { waitForHittable(close) }
    }

    @MainActor
    private func close(_ kind: String, in app: XCUIApplication) {
        let close = app.buttons["window-popup-\(kind)-close"]
        waitForHittable(close)
        close.tap()
        waitForGone(app.otherElements["window-popup-\(kind)-ready"])
    }

    @MainActor
    private func waitForHittable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            element.exists && element.isHittable
        }, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: 8)
        if result != .completed {
            let hierarchy = XCTAttachment(string: XCUIApplication().debugDescription)
            hierarchy.name = "window-ui-failure-hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "window-ui-failure-screen"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertEqual(result, .completed, file: file, line: line)
    }

    @MainActor
    private func waitForGone(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !element.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed, file: file, line: line)
    }

    @MainActor
    private func waitForValue(_ fragment: String, on element: XCUIElement,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            element.exists && (element.value as? String)?.contains(fragment) == true
        }, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: 8)
        XCTAssertEqual(result, .completed,
                       "expected fragment=\(fragment), actual value=\(String(describing: element.value)), label=\(element.label)",
                       file: file, line: line)
    }

    @MainActor
    private func revealHeader(on screen: XCUIElement) {
        let table = screen.tables["window-demo-list"]
        for _ in 0..<8 {
            if screen.staticTexts["window-role-state"].isHittable { break }
            table.swipeDown()
        }
        waitForHittable(screen.staticTexts["window-role-state"])
    }

    @MainActor
    private func outsidePoint(for button: XCUIElement, in app: XCUIApplication) -> XCUICoordinate {
        let frame = button.frame
        XCTAssertFalse(frame.isEmpty)
        // 先记录实际业务按钮的位置；遮罩显示后用真实坐标点击，不依赖被遮挡的辅助功能树。
        return app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY))
    }

    @MainActor
    func testTwoBusinessWindowsFixedAndAutomaticStackingWithOutOfOrderClose() {
        let app = launchDemo()
        let main = mainScreen(in: app)
        let mainOutside = outsidePoint(for: main.buttons["window-counter"], in: app)
        show("first", on: main, in: app)
        mainOutside.tap()
        waitForValue("main:0", on: app.staticTexts["window-popup-first-state"])
        XCTAssertTrue(app.buttons["window-popup-first-close"].isHittable)
        close("first", in: app)

        let secondary = openSecondary(in: app)
        secondary.buttons["window-counter"].tap()
        waitForValue("1", on: secondary.buttons["window-counter"])
        let outside = outsidePoint(for: secondary.buttons["window-counter"], in: app)
        show("first", on: secondary, in: app)
        outside.tap()
        waitForValue("secondary:1", on: app.staticTexts["window-popup-first-state"])
        app.buttons["window-update-live"].tap()
        XCTAssertEqual(app.staticTexts["window-popup-first-title"].label, "内容与布局已即时更新")
        waitForValue("key:popover", on: app.staticTexts["window-popup-first-state"])
        app.buttons["window-stack-fixed"].tap()
        waitForValue("active:2;ready:2", on: app.staticTexts["window-popup-first-state"])
        // 固定低层不能遮住首层；真实点击首层关闭后，固定低层才可操作。
        close("first", in: app)
        waitForReady("fixed", in: app)
        close("fixed", in: app)
        waitForHittable(secondary.buttons["window-counter"])

        show("first", on: secondary, in: app)
        app.buttons["window-stack-auto"].tap()
        waitForReady("auto", in: app)
        waitForValue("active:2;ready:2", on: app.staticTexts["window-popup-auto-state"])
        app.buttons["window-close-first"].tap()
        waitForValue("active:1;ready:1", on: app.staticTexts["window-popup-auto-state"])
        XCTAssertTrue(app.buttons["window-popup-auto-close"].isHittable)
        close("auto", in: app)
        waitForHittable(secondary.buttons["window-counter"])
        revealHeader(on: secondary)
        waitForValue("secondary", on: secondary.staticTexts["window-key-state"])
        secondary.buttons["window-counter"].tap()
        waitForValue("2", on: secondary.buttons["window-counter"])
        secondary.buttons["window-close-business"].tap()
        waitForHittable(main.buttons["window-counter"])
        revealHeader(on: main)
        waitForValue("main:0;secondary:2;closed:1", on: main.staticTexts["window-counter-state"])
        waitForValue("active:0;dismissed:5", on: main.staticTexts["window-popover-state"])
    }

    @MainActor
    func testInputTakesAndRestoresKeyThenPreservePolicyLeavesBusinessKey() {
        let app = launchDemo()
        let secondary = openSecondary(in: app)
        show("input", on: secondary, in: app)
        waitForValue("key:popover", on: app.staticTexts["window-input-title"])
        let input = app.textFields["window-input-field"]
        waitForHittable(input)
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
        input.typeText("Window Input")
        waitForHittable(app.buttons["window-input-confirm"])
        app.buttons["window-input-confirm"].tap()
        waitForGone(app.otherElements["window-popup-input-ready"])
        waitForGone(app.keyboards.firstMatch)
        revealHeader(on: secondary)
        waitForValue("Window Input", on: secondary.staticTexts["window-input-state"])
        waitForValue("secondary", on: secondary.staticTexts["window-key-state"])

        show("preserve", on: secondary, in: app)
        waitForValue("key:secondary", on: app.staticTexts["window-popup-preserve-state"])
        close("preserve", in: app)
        revealHeader(on: secondary)
        waitForValue("secondary", on: secondary.staticTexts["window-key-state"])
        secondary.buttons["window-counter"].tap()
        waitForValue("1", on: secondary.buttons["window-counter"])
    }

    @MainActor
    func testTransparentOutsideTapClosesWithoutActivatingBusinessButton() {
        let app = launchDemo()
        let main = mainScreen(in: app)
        let outside = outsidePoint(for: main.buttons["window-counter"], in: app)
        show("transparent", on: main, in: app)
        outside.tap()
        waitForGone(app.otherElements["window-popup-transparent-ready"])
        waitForHittable(main.buttons["window-counter"])
        waitForValue("0", on: main.buttons["window-counter"])
        main.buttons["window-counter"].tap()
        waitForValue("1", on: main.buttons["window-counter"])
    }

    @MainActor
    func testPassthroughCountsOnceAutoDismissesAndRespectsVeto() {
        let app = launchDemo()
        let secondary = openSecondary(in: app)
        let outside = outsidePoint(for: secondary.buttons["window-counter"], in: app)
        show("passthrough", on: secondary, in: app)
        outside.tap()
        waitForValue("secondary:1", on: app.staticTexts["window-popup-passthrough-state"])
        XCTAssertTrue(app.buttons["window-popup-passthrough-close"].isHittable)
        close("passthrough", in: app)

        show("penetrate-dismiss", on: secondary, in: app)
        outside.tap()
        waitForGone(app.otherElements["window-popup-penetrate-dismiss-ready"])
        waitForValue("2", on: secondary.buttons["window-counter"])

        show("veto", on: secondary, in: app)
        outside.tap()
        waitForValue("secondary:3;veto:1", on: app.staticTexts["window-popup-veto-state"])
        XCTAssertTrue(app.buttons["window-popup-veto-close"].isHittable)
        close("veto", in: app)
        waitForValue("3", on: secondary.buttons["window-counter"])
        secondary.buttons["window-close-business"].tap()
        let main = mainScreen(in: app)
        waitForHittable(main.buttons["window-counter"])
        revealHeader(on: main)
        waitForValue("main:0;secondary:3;closed:1", on: main.staticTexts["window-counter-state"])
    }

    @MainActor
    func testClosingSourceBusinessWindowThroughPopoverCleansItsWindow() {
        let app = launchDemo()
        let main = mainScreen(in: app)
        revealHeader(on: main)
        let baseline = main.staticTexts["window-count-state"].value as? String
        XCTAssertNotNil(baseline)
        let secondary = openSecondary(in: app)
        secondary.buttons["window-counter"].tap()
        let closeSource = outsidePoint(for: secondary.buttons["window-close-business"], in: app)
        show("source-close", on: secondary, in: app)
        closeSource.tap()
        waitForGone(app.otherElements["window-popup-source-close-ready"])
        waitForGone(secondary)
        waitForHittable(main.buttons["window-counter"])
        main.buttons["window-counter"].tap()
        revealHeader(on: main)
        waitForValue("main:1;secondary:1;closed:1", on: main.staticTexts["window-counter-state"])
        waitForValue("active:0;dismissed:1", on: main.staticTexts["window-popover-state"])
        waitForValue("main", on: main.staticTexts["window-key-state"])
        waitForValue(baseline ?? "", on: main.staticTexts["window-count-state"])
    }

    @MainActor
    func testNavigationPopCloseWholeStackAndSceneEntrypoints() {
        let app = launchDemo()
        let main = mainScreen(in: app)
        show("navigation", on: main, in: app)
        app.buttons["window-navigation-push"].tap()
        waitForHittable(app.cells["window-navigation-pop"])
        app.cells["window-navigation-pop"].tap()
        waitForHittable(app.buttons["window-navigation-push"])
        app.buttons["window-navigation-push"].tap()
        waitForHittable(app.cells["window-navigation-close-stack"])
        app.cells["window-navigation-close-stack"].tap()
        waitForGone(app.tables["window-navigation-detail"])
        waitForHittable(main.buttons["window-counter"])
        revealHeader(on: main)
        waitForValue("active:0;dismissed:1", on: main.staticTexts["window-popover-state"])

        // 同一用例覆盖 Scene 显式路由和自动导航便利入口，全程不触发键盘。
        show("scene", on: main, in: app)
        close("scene", in: app)
        show("automatic", on: main, in: app)
        close("automatic", in: app)
        show("automatic-nav", on: main, in: app)
        app.buttons["window-navigation-push"].tap()
        waitForHittable(app.cells["window-navigation-close-stack"])
        app.cells["window-navigation-close-stack"].tap()
        waitForHittable(main.buttons["window-counter"])
    }

    @MainActor
    func testWindowSceneActivationAndDestructionWhenSupported() throws {
        let app = launchDemo()
        let main = mainScreen(in: app)
        let sceneSupport = tapRow("activate-scene", on: main)
        if sceneSupport == "unsupported" {
            throw XCTSkip("当前设备不支持第二 Scene；窗口导航及显式 Scene 入口由独立用例验证。")
        }
        let additional = app.otherElements["window-additional-scene-screen"].firstMatch
        XCTAssertTrue(additional.waitForExistence(timeout: 15))
        waitForHittable(app.buttons["window-close-scene"].firstMatch)
        app.buttons["window-close-scene"].firstMatch.tap()
        let event = additional.staticTexts["window-event-state"]
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !additional.exists || (event.exists && (event.value as? String)?.hasPrefix("scene-close-error:") == true)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 15), .completed)
        if additional.exists {
            if event.value as? String == "scene-close-error:SBApplicationSupportService:1" {
                throw XCTSkip("第二 Scene 已真实激活；系统拒绝销毁此设备类型的 Scene。")
            }
            XCTFail("第二 Scene 未关闭：\(event.label)")
            return
        }
        app.activate()
        waitForHittable(main.buttons["window-counter"])
        main.buttons["window-counter"].tap()
        waitForValue("1", on: main.buttons["window-counter"])
    }
}
