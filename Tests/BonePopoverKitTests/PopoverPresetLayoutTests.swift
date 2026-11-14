import XCTest
@testable import BonePopoverKit

final class PopoverPresetLayoutTests: XCTestCase {
    @MainActor
    func testAlertUsesLocalPaddingInsideAsymmetricNavigationSafeArea() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 900))
        let presenter = UINavigationController(rootViewController: UIViewController())
        presenter.additionalSafeAreaInsets = UIEdgeInsets(top: 72, left: 0, bottom: 0, right: 84)
        window.rootViewController = presenter
        window.isHidden = false
        defer { window.isHidden = true }
        presenter.view.frame = window.bounds
        presenter.view.layoutIfNeeded()
        let alert = BoneAlertView(title: "标题应在顶部", message: "确认和取消按钮应完整填满内容宽度，左右留白一致。") {}
        XCTAssertTrue(alert.show(from: presenter, animated: false))
        defer { alert.dismissPopover(animated: false) }
        let host = try XCTUnwrap(alert.presentationHost)
        host.layoutIfNeeded()
        let title = alert.titleLabel.convert(alert.titleLabel.bounds, to: alert.baseView)
        let confirm = alert.confirmButton.convert(alert.confirmButton.bounds, to: alert.baseView)
        let cancel = alert.cancelButton.convert(alert.cancelButton.bounds, to: alert.baseView)
        XCTAssertEqual(title.minY, 24, accuracy: 1)
        XCTAssertEqual(cancel.minX, 24, accuracy: 1)
        XCTAssertEqual(confirm.maxX, alert.baseView.bounds.width - 24, accuracy: 1)
        XCTAssertEqual(cancel.width, confirm.width, accuracy: 1)
        XCTAssertEqual(confirm.minY, cancel.minY, accuracy: 1)
        XCTAssertEqual(confirm.minX - cancel.maxX, 12, accuracy: 1)
        XCTAssertEqual(alert.baseView.bounds.height - cancel.maxY, 24, accuracy: 1)
    }

    @MainActor
    func testSheetKeepsTableRowsFullWidthAfterFoldRegionChange() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 900))
        let presenter = UIViewController()
        presenter.additionalSafeAreaInsets = UIEdgeInsets(top: 50, left: 30, bottom: 34, right: 84)
        window.rootViewController = presenter
        window.isHidden = false
        defer { window.isHidden = true }
        presenter.view.frame = window.bounds
        let sheet = BoneDrawerSheetView(title: "操作列表")
        sheet.addButton(text: "分享")
        sheet.addButton(text: "归档")
        sheet.titleAlignment = .right
        XCTAssertTrue(sheet.show(from: presenter, animated: false))
        defer { sheet.dismissPopover(animated: false) }
        let host = try XCTUnwrap(sheet.presentationHost)
        for folded in [false, true, false] {
            sheet.reservedRegionProvider = { view in
                folded ? [CGRect(x: view.bounds.midX - 12, y: 0, width: 24, height: view.bounds.height)] : []
            }
            host.layoutIfNeeded()
            sheet.tableView.layoutIfNeeded()
            let close = sheet.closeButton.convert(sheet.closeButton.bounds, to: sheet.baseView)
            let title = sheet.titleLabel.convert(sheet.titleLabel.bounds, to: sheet.baseView)
            XCTAssertEqual(close.minX, 16, accuracy: 1)
            XCTAssertEqual(title.midY, close.midY, accuracy: 1)
            XCTAssertGreaterThanOrEqual(close.minY, 0)
            XCTAssertEqual(sheet.titleLabel.textAlignment, .right)
            let table = sheet.tableView.convert(sheet.tableView.bounds, to: sheet.baseView)
            XCTAssertEqual(table.minX, 0, accuracy: 1)
            XCTAssertEqual(table.maxX, sheet.baseView.bounds.width, accuracy: 1)
            XCTAssertEqual(sheet.tableView.numberOfRows(inSection: 0), 2)
            for row in 0..<2 {
                let cell = try XCTUnwrap(sheet.tableView.cellForRow(at: IndexPath(row: row, section: 0)))
                cell.layoutIfNeeded()
                let frame = cell.convert(cell.bounds, to: sheet.baseView)
                XCTAssertEqual(frame.minX, table.minX, accuracy: 1)
                XCTAssertEqual(frame.maxX, table.maxX, accuracy: 1)
                XCTAssertEqual(frame.height, sheet.sheetConfig.cellHeight, accuracy: 1)
            }
        }
    }

    @MainActor
    func testTitleAlignmentAppliesBeforeLoadingAndUpdatesWithoutChangingMessage() {
        for alignment in [NSTextAlignment.left, .center, .right] {
            let alert = BoneAlertView(title: "确认", message: "正文保持自然对齐") {}
            alert.titleAlignment = alignment
            alert.loadViewIfNeeded()
            XCTAssertEqual(alert.titleLabel.textAlignment, alignment)
            XCTAssertEqual(alert.messageLabel.textAlignment, .natural)
            alert.titleAlignment = .right
            XCTAssertEqual(alert.titleLabel.textAlignment, .right)

            let input = BoneAlertView(title: "输入", placeholder: "文本") { _ in }
            input.titleAlignment = alignment
            input.loadViewIfNeeded()
            XCTAssertEqual(input.titleLabel.textAlignment, alignment)

            let sheet = BoneDrawerSheetView(title: "操作", message: "说明")
            sheet.titleAlignment = alignment
            sheet.loadViewIfNeeded()
            XCTAssertEqual(sheet.titleLabel.textAlignment, alignment)
            sheet.titleAlignment = .center
            XCTAssertEqual(sheet.titleLabel.textAlignment, .center)
            XCTAssertEqual(sheet.messageLabel.textAlignment, .natural)
        }
    }

    /// 阅读器默认头部：标题左侧向下箭头关闭按钮，点击关闭；showsCloseButton = false 可隐藏。
    @MainActor
    func testOperationListCloseButtonDismissesAndCanBeHidden() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.isHidden = false
        defer { window.isHidden = true }
        presenter.view.frame = window.bounds

        let sheet = BoneDrawerSheetView(title: "项目操作")
        sheet.addButton(text: "分享")
        XCTAssertTrue(sheet.showsCloseButton)
        XCTAssertTrue(sheet.show(from: presenter, animated: false))
        defer { sheet.dismissPopover(animated: false) }
        let host = try XCTUnwrap(sheet.presentationHost)
        host.layoutIfNeeded()
        XCTAssertNotNil(sheet.closeButton.superview)
        let closeFrame = sheet.closeButton.convert(sheet.closeButton.bounds, to: sheet.baseView)
        let titleFrame = sheet.titleLabel.convert(sheet.titleLabel.bounds, to: sheet.baseView)
        XCTAssertEqual(closeFrame.minX, BoneDrawerSheetView.SheetConfig().headerInset, accuracy: 0.5)
        XCTAssertEqual(closeFrame.midY, titleFrame.midY, accuracy: 0.5)
        // 检查按钮最左侧也可点击，避免按钮左移到标题行之外而丢失命中区域。
        let hit = sheet.baseView.hitTest(CGPoint(x: closeFrame.minX + 1, y: closeFrame.midY), with: nil)
        XCTAssertTrue(hit === sheet.closeButton || hit?.isDescendant(of: sheet.closeButton) == true)
        XCTAssertEqual(sheet.closeButton.frame.width, 40, accuracy: 1)
        XCTAssertEqual(sheet.closeButton.frame.height, 40, accuracy: 1)
        let hasChevron = sheet.closeButton.image(for: .normal) != nil
            || sheet.closeButton.configuration?.image != nil
        XCTAssertTrue(hasChevron, "关闭按钮应有向下箭头图标")
        let dismissed = expectation(description: "close button dismisses the sheet")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        sheet.closeButton.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(sheet.presentationState, .hidden)

        let plain = BoneDrawerSheetView(title: "无关闭按钮")
        plain.showsCloseButton = false
        plain.loadViewIfNeeded()
        XCTAssertTrue(plain.closeButton.isHidden, "隐藏后关闭按钮不可见且不参与命中测试")
        XCTAssertTrue(plain.closeButton.isDescendant(of: plain.baseView), "隐藏时保留按钮层级与约束")
        plain.showsCloseButton = true
        XCTAssertFalse(plain.closeButton.isHidden, "显示期间重新开启应立即恢复关闭按钮")
    }

    /// 左对齐避让关闭按钮；按钮显隐、尺寸和表头边距变化后立即重排，居中始终以面板为准。
    @MainActor
    func testSheetTitleLeadingFollowsCloseButtonAndAlignment() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.isHidden = false
        defer { window.isHidden = true }
        presenter.view.frame = window.bounds

        let sheet = BoneDrawerSheetView(title: "项目操作")
        sheet.addButton(text: "分享")
        sheet.titleAlignment = .left
        XCTAssertTrue(sheet.show(from: presenter, animated: false))
        defer { sheet.dismissPopover(animated: false) }
        let host = try XCTUnwrap(sheet.presentationHost)
        host.layoutIfNeeded()
        sheet.baseView.layoutIfNeeded()
        func titleFrame() -> CGRect {
            sheet.titleLabel.convert(sheet.titleLabel.bounds, to: sheet.baseView)
        }
        // 16 点表头边距 + 40 点按钮 + 8 点间距。
        XCTAssertEqual(titleFrame().minX, 64, accuracy: 1, "左对齐标题应从关闭按钮右侧起排")

        sheet.showsCloseButton = false
        sheet.baseView.layoutIfNeeded()
        XCTAssertEqual(titleFrame().minX, 16, accuracy: 1, "隐藏关闭按钮后标题应回到表头左边距")

        sheet.showsCloseButton = true
        sheet.titleAlignment = .center
        sheet.baseView.layoutIfNeeded()
        XCTAssertEqual(sheet.titleLabel.textAlignment, .center)
        XCTAssertEqual(titleFrame().midX, sheet.baseView.bounds.midX, accuracy: 1,
                       "居中标题应以面板中心为准")

        sheet.confirmTitle = "全部恢复"
        sheet.onTrailingButtonTap = {}
        host.layoutIfNeeded()
        XCTAssertFalse(sheet.trailingButton.isHidden)
        XCTAssertEqual(titleFrame().midX, sheet.baseView.bounds.midX, accuracy: 1,
                       "宽度不同的左右按钮不应推偏居中标题")

        sheet.titleAlignment = .left
        sheet.configuration.contentStyle.closeButtonSize = 52
        host.layoutIfNeeded()
        XCTAssertEqual(sheet.closeButton.bounds.width, 52, accuracy: 1)
        XCTAssertEqual(sheet.closeButton.bounds.height, 52, accuracy: 1)
        XCTAssertEqual(titleFrame().minX, 16 + 52 + 8, accuracy: 1,
                       "修改关闭按钮尺寸应同步标题避让约束")

        sheet.sheetConfig.headerInset = 24
        host.layoutIfNeeded()
        let close = sheet.closeButton.convert(sheet.closeButton.bounds, to: sheet.baseView)
        let trailing = sheet.trailingButton.convert(sheet.trailingButton.bounds, to: sheet.baseView)
        XCTAssertEqual(close.minX, 24, accuracy: 1)
        XCTAssertEqual(sheet.baseView.bounds.width - trailing.maxX, 24, accuracy: 1)
        XCTAssertEqual(titleFrame().minX, 24 + 52 + 8, accuracy: 1)
        XCTAssertEqual(titleFrame().midY, close.midY, accuracy: 1)
        sheet.titleAlignment = .center
        host.layoutIfNeeded()
        XCTAssertEqual(titleFrame().midX, sheet.baseView.bounds.midX, accuracy: 1)

        sheet.configuration.contentStyle.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: 20, bottom: 20, trailing: 60)
        host.layoutIfNeeded()
        XCTAssertEqual(titleFrame().midX, sheet.baseView.bounds.midX, accuracy: 1,
                       "自定义不对称内容边距不应推偏居中表头")
    }
}
