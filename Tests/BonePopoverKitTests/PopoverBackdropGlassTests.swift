import XCTest
@testable import BonePopoverKit

/// 遮罩玻璃开关：默认关闭，开启后只虚化不改变压暗强度，并跟随呈现与关闭。
@MainActor
final class PopoverBackdropGlassTests: XCTestCase {
    private func present(_ popover: BonePopoverView) throws -> (UIWindow, UIViewController, PopoverHostView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.view.frame = window.bounds
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        host.layoutIfNeeded()
        return (window, presenter, host)
    }

    /// 不设置就保持旧行为：没有模糊层，遮罩仍是 0.32 的纯色。
    func testBackdropGlassIsOffByDefault() throws {
        let alert = BoneAlertView(title: "标题", message: "正文") {}
        let (window, _, host) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }

        XCTAssertFalse(alert.configuration.appearance.backdropGlass)
        XCTAssertTrue(host.backdropGlassView.isHidden, "默认不画玻璃层")
        XCTAssertNil(host.backdropGlassView.effect)
        XCTAssertEqual(host.backdropDimmingView.alpha, 0.32, accuracy: 0.001)
        XCTAssertEqual(host.backdropDimmingView.backgroundColor, .black)
    }

    /// 打开玻璃：模糊层出现，压暗强度仍由 backdropOpacity 决定，两者互不影响。
    func testGlassBackdropBlursWithoutChangingDimming() throws {
        let alert = BoneAlertView(title: "标题", message: "正文") {}
        alert.configuration.appearance.backdropGlass = true
        let (window, _, host) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }

        XCTAssertFalse(host.backdropGlassView.isHidden)
        XCTAssertNotNil(host.backdropGlassView.effect, "玻璃遮罩应挂上模糊效果")
        XCTAssertEqual(host.backdropGlassView.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(host.backdropDimmingView.alpha, 0.32, accuracy: 0.001,
                       "玻璃不改变压暗强度")

        alert.configuration.appearance.backdropOpacity = 0
        XCTAssertEqual(host.backdropDimmingView.alpha, 0, accuracy: 0.001)
        XCTAssertEqual(host.backdropGlassView.alpha, 1, accuracy: 0.001,
                       "不透明度为 0 时仍是纯模糊遮罩")
    }

    /// 关闭遮罩等于整体关闭：玻璃层一起消失，避免只剩模糊。
    func testShowsBackdropFalseHidesGlassToo() throws {
        let alert = BoneAlertView(title: "标题", message: "正文") {}
        alert.configuration.appearance.backdropGlass = true
        let (window, _, host) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }

        XCTAssertFalse(host.backdropGlassView.isHidden)
        alert.configuration.showsBackdrop = false
        XCTAssertTrue(host.backdropGlassView.isHidden)
        XCTAssertNil(host.backdropGlassView.effect)
        XCTAssertEqual(host.backdropDimmingView.alpha, 0, accuracy: 0.001)
    }

    /// 自定义模糊材质与压暗色都被接受，且玻璃开关可以随时改回来。
    func testGlassStyleAndColorAreConfigurable() throws {
        let alert = BoneAlertView(title: "标题", message: "正文") {}
        alert.configuration.appearance.backdropGlass = true
        alert.configuration.appearance.backdropGlassStyle = .systemThickMaterialDark
        alert.configuration.appearance.backdropColor = UIColor.black.withAlphaComponent(0.5)
        let (window, _, host) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }

        XCTAssertNotNil(host.backdropGlassView.effect)
        XCTAssertEqual(host.backdropDimmingView.backgroundColor, UIColor.black.withAlphaComponent(0.5))

        alert.configuration.appearance.backdropGlass = false
        XCTAssertTrue(host.backdropGlassView.isHidden)
        XCTAssertNil(host.backdropGlassView.effect)
    }
}
