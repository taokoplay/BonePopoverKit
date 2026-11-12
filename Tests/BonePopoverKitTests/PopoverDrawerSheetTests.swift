import XCTest
@testable import BonePopoverKit

/// 抽屉式布局与遮罩可见性的回归测试。
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

    @MainActor
    private func drawer(selection: BoneDrawerSheetView.Selection = .single) -> BoneDrawerSheetView {
        BoneDrawerSheetView(title: "阅读设置", sections: [
            .init(title: "翻页", items: [
                .init("平移", detail: "左右平移翻页"),
                .init("仿真", detail: "纸张卷曲效果"),
                .init("上下", detail: "纵向滚动翻页")
            ]),
            .init(title: "主题", items: [.init("浅色"), .init("深色")])
        ], selection: selection)
    }

    /// 分组行按扁平顺序编号；单选点击回调、选中并关闭。
    @MainActor
    func testDrawerSingleSelectionCallsBackAndDismisses() async throws {
        let sheet = drawer()
        var selected: String?
        sheet.onSelect = { selected = $0.title }
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        sheet.setSelected(indices: [0])
        XCTAssertEqual(sheet.selectedItems.map(\.title), ["平移"])

        let dismissed = expectation(description: "single selection closes the drawer")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        let row = try XCTUnwrap(control("drawer-row-1", in: sheet.baseView) as? UIControl)
        row.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(selected, "仿真")
        XCTAssertEqual(sheet.presentationState, .hidden)
    }

    /// 多选保留弹窗并记录多项，确认按钮回传全部选中项。
    @MainActor
    func testDrawerMultipleSelectionKeepsSheetAndConfirms() async throws {
        let sheet = drawer(selection: .multiple)
        var confirmed: [String] = []
        sheet.onConfirm = { confirmed = $0.map(\.title) }
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        control("drawer-row-0", in: sheet.baseView)?.sendActions(for: .touchUpInside)
        control("drawer-row-3", in: sheet.baseView)?.sendActions(for: .touchUpInside)
        XCTAssertEqual(sheet.selectedItems.map(\.title), ["平移", "浅色"])
        XCTAssertEqual(sheet.presentationState, .presented, "多选不应自动关闭")

        let dismissed = expectation(description: "confirm closes the drawer")
        sheet.notificationDismissComplete = { dismissed.fulfill() }
        control("drawer-confirm", in: sheet.baseView)?.sendActions(for: .touchUpInside)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(confirmed, ["平移", "浅色"])
        XCTAssertEqual(sheet.presentationState, .hidden)
    }

    /// 遮罩默认按预设：确认框 0.32，且 showsBackdrop 可关闭/重新打开；底部预设默认无遮罩。
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
