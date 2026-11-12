import XCTest
@testable import BonePopoverKit

/// 抽屉式布局（沿用阅读器旧用法）与遮罩可见性的回归测试。
final class PopoverDrawerSheetTests: XCTestCase {
    @MainActor
    private func present(_ popover: BonePopoverView, width: CGFloat = 390) throws
        -> (UIWindow, UIViewController, PopoverHostView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 900))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.view.frame = window.bounds
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        host.layoutIfNeeded()
        return (window, presenter, host)
    }

    @MainActor
    private func control(_ identifier: String, in view: UIView) -> UIControl? {
        if let control = view as? UIControl, control.accessibilityIdentifier == identifier {
            return control
        }
        for subview in view.subviews {
            if let found = control(identifier, in: subview) { return found }
        }
        return nil
    }

    /// 旧用法：init(title:) + addButton(inSection:) + selectAction。
    @MainActor
    private func drawer() -> BoneDrawerSheetView {
        let sheet = BoneDrawerSheetView(title: "阅读设置")
        sheet.addButton(text: "平移", value: "0", inSection: .singleSelect("翻页", true))
        sheet.addButton(text: "仿真", value: "1", inSection: .singleSelect("翻页", false))
        sheet.addButton(text: "浅色", value: "light", inSection: .multipleSelect("主题", false))
        sheet.addButton(text: "深色", value: "dark", inSection: .multipleSelect("主题", false))
        return sheet
    }

    /// 确认提交：单选默认选中项 + 手动勾选的多选项，按分区顺序回传。
    @MainActor
    func testConfirmSubmitsSingleAndMultipleSelections() async throws {
        let sheet = drawer()
        var submitted: [String] = []
        sheet.selectAction { submitted = $0.map(\.text) }
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        XCTAssertTrue(sheet.hasConfirmOperation)
        control("drawer-row-1-1", in: sheet.baseView)?.sendActions(for: .touchUpInside)

        let dismissed = expectation(description: "confirm closes the drawer")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        control("drawer-confirm", in: sheet.baseView)?.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(submitted, ["平移", "深色"])
        XCTAssertEqual(sheet.presentationState, .hidden)
    }

    /// 单选分区内互斥：点第二行后只有它被提交。
    @MainActor
    func testSingleSelectKeepsOneRowPerSection() async throws {
        let sheet = drawer()
        var submitted: [String] = []
        sheet.selectAction { submitted = $0.map(\.text) }
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        control("drawer-row-0-1", in: sheet.baseView)?.sendActions(for: .touchUpInside)
        let dismissed = expectation(description: "confirm closes the drawer")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        control("drawer-confirm", in: sheet.baseView)?.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(submitted, ["仿真"])
    }

    /// 普通分区：点击执行回调并关闭，且不出现“确定”按钮。
    @MainActor
    func testNormalSectionRowCallsBackAndDismissesWithoutConfirm() async throws {
        let sheet = BoneDrawerSheetView(title: "阅读设置")
        var tapped = false
        sheet.addButton(text: "恢复默认") { tapped = true }
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        XCTAssertFalse(sheet.hasConfirmOperation)
        let dismissed = expectation(description: "normal row closes the drawer")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        control("drawer-row-0-0", in: sheet.baseView)?.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertTrue(tapped)
        XCTAssertEqual(sheet.presentationState, .hidden)
    }

    /// 右侧按钮可被宿主接管：自定义回调时即使没有选择型分区也显示，点击只执行回调、不自动关闭。
    @MainActor
    func testCustomTrailingButtonReplacesDefaultConfirm() throws {
        let sheet = BoneDrawerSheetView(title: "阅读设置")
        sheet.addButton(text: "恢复默认") {}
        XCTAssertFalse(sheet.hasConfirmOperation)

        var tapped = 0
        sheet.onTrailingButtonTap = { tapped += 1 }
        sheet.confirmTitle = "全部恢复"
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        let trailing = try XCTUnwrap(control("drawer-confirm", in: sheet.baseView) as? UIButton)
        XCTAssertFalse(trailing.isHidden, "自定义按钮时即使无可提交分区也应显示")
        XCTAssertEqual(trailing.configuration?.title, "全部恢复")
        trailing.sendActions(for: .touchUpInside)
        XCTAssertEqual(tapped, 1)
        XCTAssertEqual(sheet.presentationState, .presented, "自定义按钮不应自动关闭")
    }

    /// 复现 Demo 配置：7 行 3 分区，检查行数与面板高度不膨胀。
    @MainActor
    func testDemoConfigurationKeepsRowCountStable() throws {
        let sheet = BoneDrawerSheetView(title: "阅读设置")
        sheet.addButton(text: "平移", value: "0", inSection: .singleSelect("翻页", true))
        sheet.addButton(text: "仿真", value: "1", inSection: .singleSelect("翻页", false))
        sheet.addButton(text: "上下", value: "2", inSection: .singleSelect("翻页", false))
        sheet.addButton(text: "浅色", value: "light", inSection: .multipleSelect("主题", false))
        sheet.addButton(text: "深色", value: "dark", inSection: .multipleSelect("主题", false))
        sheet.addButton(text: "护眼", value: "eye", inSection: .multipleSelect("主题", false))
        sheet.addButton(text: "恢复默认", style: .highlight, inSection: .normal("")) {}
        sheet.sheetConfig.openSectionTitle = true
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        func countRows(_ view: UIView) -> Int {
            var total = 0
            if let id = view.accessibilityIdentifier, id.hasPrefix("drawer-row-"),
               !id.hasPrefix("drawer-row-bg") { total += 1 }
            for sub in view.subviews { total += countRows(sub) }
            return total
        }
        let rows = countRows(sheet.baseView)
        XCTAssertEqual(rows, 7)
        XCTAssertLessThan(sheet.baseView.bounds.height, 600)
    }

    /// 标题行：左侧关闭按钮、右侧自定义按钮（默认“确定”），确认回调可触发。
    @MainActor
    func testHeaderPlacesCloseAtTopLeftAndTrailingButtonAtTopRight() async throws {
        let sheet = drawer()
        var submitted: [String] = []
        sheet.selectAction { submitted = $0.map(\.text) }
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        let close = try XCTUnwrap(control("drawer-close", in: sheet.baseView))
        let confirm = try XCTUnwrap(control("drawer-confirm", in: sheet.baseView))
        let bounds = sheet.baseView.bounds
        XCTAssertLessThan(close.frame.midX, bounds.midX, "关闭按钮应在左上角")
        XCTAssertLessThan(close.frame.maxY, 80, "关闭按钮应贴近顶部")
        XCTAssertGreaterThan(confirm.frame.midX, bounds.midX, "自定义按钮应在右上角")
        XCTAssertFalse(confirm.isHidden)

        let dismissed = expectation(description: "confirm closes the drawer")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        confirm.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(submitted, ["平移"])
    }

    /// 行背景色与分组圆角：默认次级背景，首行圆上两角、末行圆下两角；改配置后立即生效。
    @MainActor
    func testRowBackgroundColorAndGroupedCorners() throws {
        let sheet = drawer()
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        func background(of identifier: String) throws -> UIView {
            let row = try XCTUnwrap(control(identifier, in: sheet.baseView))
            return try XCTUnwrap(row.subviews.first { $0.accessibilityIdentifier == "drawer-row-bg" })
        }

        let first = try background(of: "drawer-row-0-0")
        let last = try background(of: "drawer-row-0-1")
        XCTAssertEqual(first.backgroundColor, .secondarySystemBackground, "默认行背景为次级背景色")
        XCTAssertEqual(first.layer.maskedCorners, [.layerMinXMinYCorner, .layerMaxXMinYCorner])
        XCTAssertEqual(last.layer.maskedCorners, [.layerMinXMaxYCorner, .layerMaxXMaxYCorner])

        sheet.sheetConfig.cellBackgroundColor = .systemRed
        sheet.sheetConfig.cellCornerRadius = 4
        let updated = try background(of: "drawer-row-0-0")
        XCTAssertEqual(updated.backgroundColor, .systemRed)
        XCTAssertEqual(updated.layer.cornerRadius, 4, accuracy: 0.1)
    }

    /// 遮罩默认按预设：确认框 0.32；showsBackdrop 可关闭/重开；底部预设默认无遮罩。
    @MainActor
    func testBackdropDimmingFollowsPresetAndShowsBackdrop() throws {
        let alert = BoneAlertView(title: "标题", message: "正文") {}
        let (window, _, host) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(host.backdropDimmingView.alpha, 0.32, accuracy: 0.01, "确认框默认应有遮罩")

        alert.configuration.showsBackdrop = false
        XCTAssertEqual(host.backdropDimmingView.alpha, 0, accuracy: 0.01)

        alert.configuration.showsBackdrop = true
        XCTAssertEqual(host.backdropDimmingView.alpha, 0.32, accuracy: 0.01)

        let sheet = BoneActionSheetView(title: "操作", actions: [PopoverAction("分享")])
        let (sheetWindow, _, sheetHost) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); sheetWindow.isHidden = true }
        XCTAssertEqual(sheetHost.backdropDimmingView.alpha, 0, accuracy: 0.01,
                       "阅读器默认底栏不带遮罩")

        sheet.configuration.showsBackdrop = true
        XCTAssertEqual(sheetHost.backdropDimmingView.alpha, 0.32, accuracy: 0.01)
    }
}
