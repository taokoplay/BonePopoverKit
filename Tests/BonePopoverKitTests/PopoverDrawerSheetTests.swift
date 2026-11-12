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
