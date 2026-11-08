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
}
