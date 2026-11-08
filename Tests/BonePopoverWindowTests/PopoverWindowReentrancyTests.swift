import XCTest
@testable import BonePopoverKit

@MainActor
private final class ReentrantWindowPopover: BonePopoverView {
    var cancelWhileAdding = false
    var duringDisappearance: (() -> Void)?
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent != nil && cancelWhileAdding { dismissPopover(animated: false) }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let action = duringDisappearance
        duringDisappearance = nil
        action?()
    }
}

@MainActor
private final class HiddenWindowAction: NSObject {
    let action: () -> Void
    init(window: UIWindow, action: @escaping () -> Void) {
        self.action = action
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(fire(_:)), name: UIWindow.didBecomeHiddenNotification, object: window)
    }
    @objc private func fire(_ note: Notification) { action() }
    func invalidate() { NotificationCenter.default.removeObserver(self) }
}

final class PopoverWindowReentrancyTests: XCTestCase {
    @MainActor
    private func source() throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        return window
    }

    @MainActor
    func testCancelDuringAddChildRollsBackBothPresentationModes() throws {
        let source = try source()
        defer { source.isHidden = true }
        for usesWindow in [false, true] {
            let popover = ReentrantWindowPopover(configuration: .centerDialog)
            popover.cancelWhileAdding = true
            XCTAssertFalse(usesWindow ? popover.show(over: source, animated: false)
                : popover.show(from: source.rootViewController!, animated: false))
            XCTAssertEqual(popover.presentationState, .hidden)
            XCTAssertNil(popover.parent)
            XCTAssertNil(popover.view.superview)
            popover.cancelWhileAdding = false
            XCTAssertTrue(popover.show(over: source, animated: false))
            popover.dismissPopover(animated: false)
        }
    }

    @MainActor
    func testDisappearanceReentrancyDoesNotRemoveReshownSession() throws {
        let source = try source()
        defer { source.isHidden = true }
        let popover = ReentrantWindowPopover(configuration: .centerDialog)
        var notifications = 0
        popover.notificationDismissComplete = { notifications += 1 }
        XCTAssertTrue(popover.show(over: source, animated: false))
        popover.duringDisappearance = { [weak popover] in
            popover?.dismissPopover(animated: false, reason: .hostRemoved)
        }
        popover.dismissPopover(animated: false) {
            XCTAssertTrue(popover.show(over: source, animated: false))
        }
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(popover.presentationState, .presented)
        XCTAssertNotNil(popover.view.window)
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testDismissVetoCallbackCanReshowWithoutClosingNewPresentation() throws {
        let source = try source()
        defer { source.isHidden = true }
        let popover = BonePopoverView(configuration: .centerDialog)
        XCTAssertTrue(popover.show(over: source, animated: false))
        let originalID = popover.presentationIdentifier
        popover.shouldDismiss = { [weak popover] _ in
            popover?.dismissPopover(animated: false) {
                XCTAssertTrue(popover?.show(over: source, animated: false) ?? false)
            }
            return true
        }
        XCTAssertFalse(popover.requestDismiss(reason: .penetration))
        XCTAssertNotEqual(originalID, popover.presentationIdentifier)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.shouldDismiss = nil
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testNewKeyWindowFromHiddenNotificationIsPreserved() throws {
        let source = try source()
        defer { source.isHidden = true }
        let first = BonePopoverView(configuration: .centerDialog)
        let second = BonePopoverView(configuration: .centerDialog)
        XCTAssertTrue(first.show(over: source, animated: false))
        let oldWindow = try XCTUnwrap(first.view.window)
        let observer = HiddenWindowAction(window: oldWindow) {
            XCTAssertTrue(second.show(over: source, animated: false))
        }
        defer { observer.invalidate() }
        first.dismissPopover(animated: false)
        XCTAssertTrue(second.view.window?.isKeyWindow == true)
        XCTAssertEqual(second.presentationState, .presented)
        observer.invalidate()
        second.dismissPopover(animated: false)
    }

    @MainActor
    func testRemovingOffscreenNavigationRootEndsWindowSession() async throws {
        let source = try source()
        defer { source.isHidden = true }
        let popover = BonePopoverView(configuration: .centerDialog)
        popover.configuration.window.container = .navigation
        XCTAssertTrue(popover.show(over: source, animated: false))
        let navigation = try XCTUnwrap(popover.navigationController)
        let detail = UIViewController()
        navigation.pushViewController(detail, animated: false)
        let removed = expectation(description: "navigation root removed")
        popover.notificationDismissComplete = { removed.fulfill() }
        navigation.setViewControllers([detail], animated: false)
        await fulfillment(of: [removed], timeout: 3)
        XCTAssertEqual(popover.presentationState, .hidden)
        XCTAssertNil(popover.parent)
        XCTAssertNil(popover.windowSession)
    }

    @MainActor
    func testEqualLevelUpperWindowIsNotObservedByLowerPopover() throws {
        let source = try source()
        defer { source.isHidden = true }
        let first = BonePopoverView(configuration: .centerDialog)
        let second = BonePopoverView(configuration: .centerDialog)
        for popover in [first, second] {
            popover.configuration.window.level = .normal + 100
            popover.configuration.window.stacking = .fixed
        }
        XCTAssertTrue(first.show(over: source, animated: false))
        XCTAssertTrue(second.show(over: source, animated: false))
        let upperWindow = try XCTUnwrap(second.view.window)
        let baseline = upperWindow.gestureRecognizers?.count ?? 0
        first.configuration.allowsEventPenetration = true
        first.configuration.autoHideWhenPenetrated = true
        XCTAssertEqual(upperWindow.gestureRecognizers?.count ?? 0, baseline)
        first.dismissPopover(animated: false)
        second.dismissPopover(animated: false)
    }
}
