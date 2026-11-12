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

    /// 抽屉改用 UITableView 后，行是 cell；按标识在层级里找。
    @MainActor
    private func cell(_ identifier: String, in view: UIView) -> UITableViewCell? {
        if let cell = view as? UITableViewCell, cell.accessibilityIdentifier == identifier {
            return cell
        }
        for subview in view.subviews {
            if let found = cell(identifier, in: subview) { return found }
        }
        return nil
    }

    /// 模拟点击某一行：直接走 table view 的选中回调，等价于用户点这一行。
    @MainActor
    private func tapRow(_ sheet: BoneDrawerSheetView, _ indexPath: IndexPath) {
        sheet.tableView.layoutIfNeeded()
        sheet.tableView(sheet.tableView, didSelectRowAt: indexPath)
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

    /// 右侧按钮默认隐藏；显式打开后才出现，且点击才提交。
    @MainActor
    func testTrailingButtonHiddenByDefault() throws {
        let sheet = drawer()
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }
        let trailing = try XCTUnwrap(control("drawer-confirm", in: sheet.baseView))
        XCTAssertTrue(trailing.isHidden, "默认不显示右侧按钮")
        XCTAssertTrue(sheet.hasConfirmOperation, "分区仍是选择型，只是不自动显示按钮")
    }

    /// 确认提交：单选默认选中项 + 手动勾选的多选项，按分区顺序回传。
    @MainActor
    func testConfirmSubmitsSingleAndMultipleSelections() async throws {
        let sheet = drawer()
        var submitted: [String] = []
        sheet.selectAction { submitted = $0.map(\.text) }
        sheet.showsConfirmButton = true
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        XCTAssertTrue(sheet.hasConfirmOperation)
        tapRow(sheet, IndexPath(row: 1, section: 1))

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
        sheet.showsConfirmButton = true
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        tapRow(sheet, IndexPath(row: 1, section: 0))
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
        tapRow(sheet, IndexPath(row: 0, section: 0))
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
               !id.hasPrefix("drawer-row-bg"), !id.hasPrefix("drawer-row-icon") { total += 1 }
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
        sheet.showsConfirmButton = true
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        let close = try XCTUnwrap(control("drawer-close", in: sheet.baseView))
        let confirm = try XCTUnwrap(control("drawer-confirm", in: sheet.baseView))
        let bounds = sheet.baseView.bounds
        XCTAssertLessThan(close.frame.midX, bounds.midX, "关闭按钮应在左上角")
        let closeImage = (close as? UIButton)?.configuration?.image ?? (close as? UIButton)?.image(for: .normal)
        XCTAssertNotNil(closeImage, "关闭按钮应使用向下箭头（与操作列表一致）")
        XCTAssertLessThan(close.frame.maxY, 80, "关闭按钮应贴近顶部")
        XCTAssertGreaterThan(confirm.frame.midX, bounds.midX, "自定义按钮应在右上角")
        XCTAssertFalse(confirm.isHidden)

        let dismissed = expectation(description: "confirm closes the drawer")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        confirm.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(submitted, ["平移"])
    }

    /// 右侧按钮沿用左侧关闭按钮的外观：同一高度、同一胶囊玻璃样式，只把图标换成文字。
    @MainActor
    func testConfirmButtonSharesCloseButtonStyle() throws {
        let sheet = drawer()
        sheet.showsConfirmButton = true
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        let close = try XCTUnwrap(control("drawer-close", in: sheet.baseView) as? UIButton)
        let confirm = try XCTUnwrap(control("drawer-confirm", in: sheet.baseView) as? UIButton)
        print("button-frames close=\(close.frame) confirm=\(confirm.frame)")

        XCTAssertEqual(confirm.frame.height, close.frame.height, accuracy: 0.5, "两个按钮高度必须一致")
        XCTAssertGreaterThanOrEqual(confirm.frame.width, close.frame.width - 0.5, "文字按钮不应比关闭按钮更窄")
        XCTAssertLessThanOrEqual(confirm.frame.width - confirm.frame.height, 14, "两字标题应接近圆形，与左侧按钮直径相当")
        if #available(iOS 26.0, *) {
            XCTAssertEqual(confirm.configuration?.cornerStyle, close.configuration?.cornerStyle,
                           "确认按钮应与关闭按钮同为胶囊玻璃样式")
        }
        XCTAssertNil(confirm.configuration?.image, "确认按钮的内容是文字")
        XCTAssertEqual(confirm.configuration?.title ?? confirm.title(for: .normal), "确定")
    }

    /// 行背景色与分组圆角：默认次级背景，首行圆上两角、末行圆下两角；改配置后立即生效。
    @MainActor
    func testRowBackgroundColorAndGroupedCorners() throws {
        let sheet = drawer()
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        func background(of identifier: String) throws -> UIView {
            let row = try XCTUnwrap(cell(identifier, in: sheet.baseView))
            func find(_ view: UIView) -> UIView? {
                if view.accessibilityIdentifier == "drawer-row-bg" { return view }
                for sub in view.subviews { if let hit = find(sub) { return hit } }
                return nil
            }
            return try XCTUnwrap(find(row))
        }

        let first = try background(of: "drawer-row-0-0")
        let last = try background(of: "drawer-row-0-1")
        // 分组列表配色：面板灰底、行白底（深色下分别是黑与 #1C1C1E）。
        XCTAssertEqual(sheet.configuration.appearance.backgroundColor, .systemGroupedBackground,
                       "默认面板为分组灰底")
        XCTAssertEqual(first.backgroundColor, .secondarySystemGroupedBackground, "默认行背景为白底")
        XCTAssertNotEqual(sheet.configuration.appearance.backgroundColor, first.backgroundColor)
        XCTAssertEqual(first.layer.maskedCorners, [.layerMinXMinYCorner, .layerMaxXMinYCorner])
        XCTAssertEqual(last.layer.maskedCorners, [.layerMinXMaxYCorner, .layerMaxXMaxYCorner])

        sheet.sheetConfig.cellBackgroundColor = .systemRed
        sheet.sheetConfig.cellCornerRadius = 4
        sheet.tableView.layoutIfNeeded()
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

    /// 行图标：传了 icon 才占位，底板/着色可配；不给 icon 的行保留纯文字布局。
    @MainActor
    func testRowIconIsOptionalAndConfigurable() throws {
        let sheet = BoneDrawerSheetView(title: "语言")
        sheet.addButton(text: "跟随系统", value: "system", icon: UIImage(systemName: "iphone"),
                        inSection: .singleSelect("语言", true))
        sheet.addButton(text: "English", value: "en", inSection: .singleSelect("语言", false))
        sheet.sheetConfig.cellIconBackgroundColor = .systemYellow
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        // 直接向数据源要 cell 并给一个确定的尺寸，避免依赖 table 的可见布局时机。
        func madeCell(row: Int) -> BoneDrawerSheetCell {
            let dequeued = sheet.tableView(sheet.tableView, cellForRowAt: IndexPath(row: row, section: 0))
            let cell = dequeued as! BoneDrawerSheetCell
            cell.frame = CGRect(x: 0, y: 0, width: 390, height: sheet.sheetConfig.cellHeight)
            // 单元测试里没有 run loop 的布局时机，直接跑一次布局拿到确定几何。
            cell.layoutSubviews()
            return cell
        }

        // 复用队列会返回同一个 cell，先把有图标那行的结果读出来再取下一行。
        let withIcon = madeCell(row: 0)
        let iconHidden = withIcon.iconBox.isHidden
        let iconSize = withIcon.iconBox.frame.size
        let iconColor = withIcon.iconBox.backgroundColor
        let iconRadius = withIcon.iconBox.layer.cornerRadius
        let glyphWidth = withIcon.iconBox.subviews.first?.frame.width ?? 0
        let withoutIcon = madeCell(row: 1)

        XCTAssertFalse(iconHidden, "传了 icon 的行显示图标位")
        XCTAssertTrue(withoutIcon.iconBox.isHidden, "没传 icon 的行不显示图标位")
        XCTAssertEqual(iconSize.width, sheet.sheetConfig.cellIconSize, accuracy: 0.5)
        XCTAssertEqual(iconSize.height, sheet.sheetConfig.cellIconSize, accuracy: 0.5)
        XCTAssertEqual(iconColor, .systemYellow, "底板颜色来自 sheetConfig")
        XCTAssertEqual(iconRadius, sheet.sheetConfig.cellIconCornerRadius, accuracy: 0.1)
        XCTAssertEqual(glyphWidth, sheet.sheetConfig.cellIconSize * 0.58, accuracy: 1, "图标约底板 58%")
        XCTAssertEqual(sheet.sheetConfig.headerInset, 16, "表头左右留白默认 16")
        XCTAssertEqual(sheet.tableView.style, .grouped, "列表用 grouped 样式")
    }

}
