import XCTest
@testable import BonePopoverKit

/// 操作列表的增量写法：先建面板，再逐个 addButton/addAction。
final class PopoverActionSheetBuilderTests: XCTestCase {
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

    /// 不传 actions 也能创建；逐个添加后顺序为「动作…、取消」，且都带样式。
    @MainActor
    func testSheetCreatesWithoutActionsThenAddsButtonsInOrder() throws {
        let sheet = BoneActionSheetView(title: "项目操作", message: "选择要执行的操作")
        XCTAssertTrue(sheet.actionButtons.isEmpty, "未添加动作时不应有动作按钮")

        let share = sheet.addButton("分享", image: UIImage(systemName: "square.and.arrow.up"))
        let remove = sheet.addButton("删除", role: .destructive)
        XCTAssertEqual(sheet.actionButtons.count, 2)
        XCTAssertEqual(share.configuration?.title, "分享")
        XCTAssertEqual(remove.tintColor, .systemRed, "destructive 应使用红色强调")

        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }
        sheet.baseView.layoutIfNeeded()

        let frames = ([share, remove] + [sheet.cancelButton]).map {
            $0.convert($0.bounds, to: sheet.baseView)
        }
        XCTAssertGreaterThan(frames[1].minY, frames[0].maxY, "动作按添加顺序竖排")
        XCTAssertGreaterThan(frames[2].minY, frames[1].maxY, "取消按钮固定在动作之后")
        XCTAssertEqual(share.titleLabel?.font.pointSize ?? 0, 17, accuracy: 0.01, "新增按钮应套用按钮字体")
    }

    /// addAction 保留原有动作语义：dismissesPopover: false 执行后保留弹窗，默认先关闭再回调。
    @MainActor
    func testAddedActionsKeepDismissAndCallbackSemantics() async throws {
        let sheet = BoneActionSheetView(title: "项目操作")
        var refreshCount = 0
        let refresh = sheet.addButton("刷新状态", dismissesPopover: false) { refreshCount += 1 }
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        refresh.sendActions(for: .touchUpInside)
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(sheet.presentationState, .presented, "dismissesPopover: false 应保留弹窗")

        var deleted = false
        let remove = sheet.addButton("删除") { deleted = true }
        XCTAssertEqual(sheet.actionButtons.count, 2)
        let dismissed = expectation(description: "dismissing action closes the sheet")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        remove.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertTrue(deleted, "先关闭再执行回调")
        XCTAssertEqual(sheet.presentationState, .hidden)
    }
}
