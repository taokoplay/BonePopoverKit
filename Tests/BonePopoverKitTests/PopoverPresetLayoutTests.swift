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
            XCTAssertEqual(title.minY, 24, accuracy: 1)
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
}
