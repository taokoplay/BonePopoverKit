import XCTest
@testable import BonePopoverKit

/// 阅读器旧基类（ParsingBook/Custom/BonePopoverView）里写死、SDK 改为可配置的取值：
/// 不设置时保持旧默认行为，设置后立即生效。
final class PopoverReaderParityTests: XCTestCase {
    @MainActor
    private func present(_ popover: BonePopoverView, width: CGFloat = 390) throws
        -> (UIWindow, UIViewController, PopoverHostView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 1200))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.view.frame = window.bounds
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        host.layoutIfNeeded()
        return (window, presenter, host)
    }

    /// 确认框按钮标题：默认“确认 / 取消”，可覆盖，空串回退默认，显示期间修改立即生效。
    @MainActor
    func testAlertButtonTitlesAreConfigurableWithLegacyDefaults() throws {
        let alert = BoneAlertView(title: "删除项目", message: "删除后不可恢复") {}
        let (window, _, _) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertNil(alert.confirmTitle)
        XCTAssertNil(alert.cancelTitle)
        XCTAssertEqual(alert.confirmButton.configuration?.title, "确认")
        XCTAssertEqual(alert.cancelButton.configuration?.title, "取消")

        alert.confirmTitle = "OK"
        alert.cancelTitle = "Cancel"
        XCTAssertEqual(alert.confirmButton.configuration?.title, "OK")
        XCTAssertEqual(alert.cancelButton.configuration?.title, "Cancel")

        alert.confirmTitle = ""
        alert.cancelTitle = nil
        XCTAssertEqual(alert.confirmButton.configuration?.title, "确认", "空字符串应回退默认文案")
        XCTAssertEqual(alert.cancelButton.configuration?.title, "取消")
    }

    /// 输入框预设同样生效，且可在视图加载前设置。
    @MainActor
    func testInputAlertUsesConfiguredTitlesBeforeLoading() throws {
        let alert = BoneAlertView(title: "命名项目", placeholder: "名称") { _ in }
        alert.confirmTitle = "保存"
        alert.cancelTitle = "返回"
        let (window, _, _) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(alert.confirmButton.configuration?.title, "保存")
        XCTAssertEqual(alert.cancelButton.configuration?.title, "返回")
    }

    /// 关闭按钮图标与命中区可配置；不设置时仍是 40 点与内置向下箭头。
    @MainActor
    func testActionSheetCloseButtonImageAndSizeAreConfigurable() throws {
        let sheet = BoneActionSheetView(title: "项目操作", actions: [PopoverAction("分享")])
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(sheet.closeButton.frame.width, 40, accuracy: 1)
        XCTAssertEqual(sheet.closeButton.frame.height, 40, accuracy: 1)
        let defaultImage = sheet.closeButton.configuration?.image ?? sheet.closeButton.image(for: .normal)
        XCTAssertNotNil(defaultImage, "默认应显示内置向下箭头")

        let custom = try XCTUnwrap(UIImage(systemName: "xmark"))
        var style = sheet.configuration.contentStyle
        style.closeButtonSize = 52
        style.closeButtonImage = custom
        sheet.configuration.contentStyle = style
        sheet.baseView.layoutIfNeeded()
        XCTAssertEqual(sheet.closeButton.frame.width, 52, accuracy: 1)
        XCTAssertEqual(sheet.closeButton.frame.height, 52, accuracy: 1)
        let configuredImage = sheet.closeButton.configuration?.image ?? sheet.closeButton.image(for: .normal)
        XCTAssertTrue(configuredImage === custom, "样式刷新不应覆盖宿主设置的图标")
    }

    /// 缩放动画比例可配置；不传参数保持旧默认 0.92，越界比例被夹住。
    @MainActor
    func testScaleAnimationFactorIsConfigurableWithLegacyDefault() {
        let panel = CGRect(x: 0, y: 0, width: 100, height: 100)
        let container = CGRect(x: 0, y: 0, width: 390, height: 844)
        XCTAssertEqual(PopoverAnimation.scale.hiddenState(panel, container, false).transform.a,
                       0.92, accuracy: 0.001)
        XCTAssertEqual(PopoverAnimation.scale(0.8).hiddenState(panel, container, false).transform.a,
                       0.8, accuracy: 0.001)
        XCTAssertEqual(PopoverAnimation.scale(5).hiddenState(panel, container, false).transform.a,
                       1, accuracy: 0.001)
    }

    /// 界面样式覆盖：默认 `.unspecified` 跟随宿主；设定后同时作用于宿主与弹窗内容。
    @MainActor
    func testInterfaceStyleOverrideAndDefaultInheritance() throws {
        let alert = BoneAlertView(title: "标题", message: "正文") {}
        alert.configuration.interfaceStyle = .light
        let (window, _, host) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(host.overrideUserInterfaceStyle, .light)
        XCTAssertEqual(alert.overrideUserInterfaceStyle, .light)

        alert.configuration.interfaceStyle = .unspecified
        XCTAssertEqual(host.overrideUserInterfaceStyle, .unspecified, "取消覆盖后应恢复继承宿主")
        XCTAssertEqual(alert.overrideUserInterfaceStyle, .unspecified)
    }
}
