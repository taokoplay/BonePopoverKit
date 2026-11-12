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
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
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
    func testSheetKeepsButtonsFullWidthAfterFoldRegionChange() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 900))
        let presenter = UIViewController()
        presenter.additionalSafeAreaInsets = UIEdgeInsets(top: 50, left: 30, bottom: 34, right: 84)
        window.rootViewController = presenter
        window.isHidden = false
        defer { window.isHidden = true }
        presenter.view.frame = window.bounds
        let sheet = BoneActionSheetView(title: "操作列表", actions: [PopoverAction("分享"), PopoverAction("归档")])
        sheet.titleAlignment = .right
        XCTAssertTrue(sheet.show(from: presenter, animated: false))
        defer { sheet.dismissPopover(animated: false) }
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        for folded in [false, true, false] {
            sheet.reservedRegionProvider = { view in
                folded ? [CGRect(x: view.bounds.midX - 12, y: 0, width: 24, height: view.bounds.height)] : []
            }
            host.layoutIfNeeded()
            let title = sheet.titleLabel.convert(sheet.titleLabel.bounds, to: sheet.baseView)
            // 标题行含 44 点高的关闭按钮，标题在行内垂直居中，内容顶部仍是 24 点边距。
            XCTAssertTrue(title.minY >= 23, "标题不应高于 24 点内容边距：\(title.minY)")
            XCTAssertLessThanOrEqual(title.minY, 45)
            XCTAssertEqual(sheet.titleLabel.textAlignment, .right)
            for button in sheet.actionButtons + [sheet.cancelButton] {
                let frame = button.convert(button.bounds, to: sheet.baseView)
                XCTAssertEqual(frame.minX, 24, accuracy: 1)
                XCTAssertEqual(frame.maxX, sheet.baseView.bounds.width - 24, accuracy: 1)
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

            let sheet = BoneActionSheetView(title: "操作", message: "说明", actions: [])
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
    func testActionSheetCloseButtonDismissesAndCanBeHidden() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.isHidden = false
        defer { window.isHidden = true }
        presenter.view.frame = window.bounds

        let sheet = BoneActionSheetView(title: "项目操作", actions: [PopoverAction("分享")])
        XCTAssertTrue(sheet.show(from: presenter, animated: false))
        defer { sheet.dismissPopover(animated: false) }
        XCTAssertNotNil(sheet.closeButton.superview)
        XCTAssertTrue(sheet.closeButton.superview === sheet.titleLabel.superview, "关闭按钮与标题在同一标题行")
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

        let plain = BoneActionSheetView(title: "无关闭按钮", actions: [])
        plain.showsCloseButton = false
        plain.loadViewIfNeeded()
        XCTAssertTrue(plain.closeButton.isHidden, "隐藏后关闭按钮不可见且不参与命中测试")
        XCTAssertTrue(plain.closeButton.superview === plain.titleLabel.superview, "关闭按钮始终在标题行内")
        plain.showsCloseButton = true
        XCTAssertFalse(plain.closeButton.isHidden, "显示期间重新开启应立即恢复关闭按钮")
    }

    /// 标题与关闭按钮的位置关系：左对齐避让按钮、隐藏按钮回到内容边距、
    /// 显示期间切到居中后横贯整行（阅读器默认居中标题不被按钮留白推偏）。
    @MainActor
    func testSheetTitleLeadingFollowsCloseButtonAndAlignment() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.isHidden = false
        defer { window.isHidden = true }
        presenter.view.frame = window.bounds

        let sheet = BoneActionSheetView(title: "项目操作", actions: [PopoverAction("分享")])
        sheet.titleAlignment = .left
        XCTAssertTrue(sheet.show(from: presenter, animated: false))
        defer { sheet.dismissPopover(animated: false) }
        sheet.baseView.layoutIfNeeded()
        func titleFrame() -> CGRect {
            sheet.titleLabel.convert(sheet.titleLabel.bounds, to: sheet.baseView)
        }
        // 24 点内容边距 + 40 点按钮 + 8 点间距。
        XCTAssertEqual(titleFrame().minX, 72, accuracy: 1, "左对齐标题应从关闭按钮右侧起排")

        sheet.showsCloseButton = false
        sheet.baseView.layoutIfNeeded()
        XCTAssertEqual(titleFrame().minX, 24, accuracy: 1, "隐藏关闭按钮后标题应回到内容左边距")

        sheet.showsCloseButton = true
        sheet.titleAlignment = .center
        sheet.baseView.layoutIfNeeded()
        XCTAssertEqual(sheet.titleLabel.textAlignment, .center)
        XCTAssertEqual(titleFrame().minX, 24, accuracy: 1, "居中标题应横贯整行")
        XCTAssertEqual(titleFrame().maxX, sheet.baseView.bounds.width - 24, accuracy: 1)
    }
}
