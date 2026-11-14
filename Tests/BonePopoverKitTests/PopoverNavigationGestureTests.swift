import XCTest
@testable import BonePopoverKit

final class PopoverNavigationGestureTests: XCTestCase {
    @MainActor
    func testStackedModalPopoversRestoreNavigationOnlyAfterLastDismissal() throws {
        let presenter = UIViewController()
        let navigation = UINavigationController(rootViewController: presenter)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        window.rootViewController = navigation
        window.isHidden = false
        defer { window.isHidden = true }
        navigation.view.layoutIfNeeded()
        var gestures = [navigation.interactivePopGestureRecognizer].compactMap { $0 }
        if #available(iOS 26.0, *), let content = navigation.interactiveContentPopGestureRecognizer { gestures.append(content) }
        XCTAssertFalse(gestures.isEmpty)
        gestures.forEach { $0.isEnabled = true }
        let first = BonePopoverView(configuration: .centerDialog)
        let second = BonePopoverView(configuration: .centerDialog)
        XCTAssertTrue(first.show(from: presenter, animated: false))
        XCTAssertTrue(second.show(from: presenter, animated: false))
        XCTAssertTrue(gestures.allSatisfy { !$0.isEnabled })
        first.dismissPopover(animated: false)
        XCTAssertTrue(gestures.allSatisfy { !$0.isEnabled })
        second.dismissPopover(animated: false)
        XCTAssertTrue(gestures.allSatisfy(\.isEnabled))
    }

    @MainActor
    func testPassthroughAndDismissalPreserveOriginallyDisabledNavigation() throws {
        let presenter = UIViewController()
        let navigation = UINavigationController(rootViewController: presenter)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        window.rootViewController = navigation
        window.isHidden = false
        defer { window.isHidden = true }
        navigation.view.layoutIfNeeded()
        let edge = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        edge.isEnabled = false
        let popover = BonePopoverView(configuration: .centerDialog)
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        popover.configuration.allowsEventPenetration = true
        XCTAssertFalse(edge.isEnabled)
        popover.configuration.allowsEventPenetration = false
        popover.dismissPopover(animated: false)
        XCTAssertFalse(edge.isEnabled)
    }

    /// 从导航容器展示吐司，只覆盖界面，不能把吐司加入返回栈。
    @MainActor
    func testToastShownFromNavigationDoesNotChangeItsDestinations() throws {
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        navigation.view.layoutIfNeeded()

        for style in [BoneToastView.Style.top, .bottom, .center] {
            let toast = BoneToastView(message: "已保存", style: style, duration: 0)
            XCTAssertTrue(toast.show(from: navigation, animated: false))
            defer { toast.dismissPopover(animated: false) }
            XCTAssertEqual(navigation.viewControllers.count, 1,
                           "吐司不应成为可返回的页面：\(navigation.viewControllers.map { String(describing: type(of: $0)) })")
            XCTAssertTrue(navigation.topViewController === root)
            XCTAssertTrue(navigation.visibleViewController === root)
            XCTAssertNil(navigation.popViewController(animated: false), "首页不能被吐司多出来的返回层弹出")
        }
    }

    @MainActor
    func testToastDoesNotReplaceDetailWhenNavigationReturns() throws {
        let root = UIViewController()
        let detail = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        navigation.pushViewController(detail, animated: false)
        navigation.view.layoutIfNeeded()
        let toast = BoneToastView(message: "已保存", duration: 0)
        XCTAssertTrue(toast.show(from: navigation, animated: false))
        defer { toast.dismissPopover(animated: false) }
        XCTAssertEqual(navigation.viewControllers.count, 2)
        XCTAssertTrue(navigation.topViewController === detail)
        XCTAssertTrue(navigation.popViewController(animated: false) === detail)
        navigation.view.layoutIfNeeded()
        XCTAssertTrue(navigation.visibleViewController === root)
        XCTAssertEqual(navigation.viewControllers.count, 1)
        XCTAssertEqual(toast.presentationState, .hidden, "原页面离开后也要清理附着的吐司")
    }

    @MainActor
    func testEmptyNavigationRejectsPresentationWithoutReservingState() {
        let navigation = UINavigationController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let toast = BoneToastView(message: "已保存", duration: 0)
        XCTAssertFalse(toast.show(from: navigation, animated: false))
        XCTAssertEqual(toast.presentationState, .hidden)
        XCTAssertTrue(navigation.viewControllers.isEmpty)
    }

    @MainActor
    func testTabContainerUsesItsCurrentPageAndKeepsModalBackGestureGuard() throws {
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let tabs = UITabBarController()
        tabs.viewControllers = [navigation, UIViewController()]
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        tabs.view.layoutIfNeeded()
        let edge = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        edge.isEnabled = true
        let alert = BoneAlertView(title: "确认", message: "正文") {}
        XCTAssertTrue(alert.show(from: tabs, animated: false))
        defer { alert.dismissPopover(animated: false) }
        XCTAssertTrue(alert.parent === root)
        XCTAssertEqual(tabs.viewControllers?.count, 2)
        XCTAssertEqual(navigation.viewControllers.count, 1)
        XCTAssertFalse(edge.isEnabled, "模态弹层仍应暂停页面返回手势")
        alert.dismissPopover(animated: false)
        XCTAssertTrue(edge.isEnabled)
    }
}
