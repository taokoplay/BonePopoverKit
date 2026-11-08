import XCTest
@testable import BonePopoverKit

final class PopoverPresentationTests: XCTestCase {
    @MainActor
    private func makeHost() -> (UIWindow, UIViewController) {
        let controller = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 900))
        window.rootViewController = controller
        window.isHidden = false
        controller.loadViewIfNeeded()
        controller.view.frame = window.bounds
        return (window, controller)
    }

    @MainActor
    func testContainmentDismissalAndReuse() throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = BonePopoverView(configuration: .bottomSheet)
        popover.configuration.animation = .none
        var shows = 0
        var dismissals = 0
        popover.onDidShow = { shows += 1 }
        popover.notificationDismissComplete = { dismissals += 1 }
        XCTAssertTrue(popover.show(from: presenter))
        XCTAssertFalse(popover.show(from: presenter))
        XCTAssertTrue(popover.parent === presenter)
        XCTAssertEqual(popover.presentationState, .presented)
        var completed = false
        popover.hidden { completed = true }
        XCTAssertTrue(completed)
        XCTAssertNil(popover.parent)
        XCTAssertNil(popover.view.superview)
        XCTAssertEqual(popover.presentationState, .hidden)
        XCTAssertTrue(popover.show(from: presenter))
        popover.dismissPopover(animated: false)
        XCTAssertEqual(shows, 2)
        XCTAssertEqual(dismissals, 2)
        XCTAssertTrue(presenter.children.isEmpty)
    }

    @MainActor
    func testDismissingDuringPresentationCompletesEachCallbackOnce() async {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = BonePopoverView(configuration: .bottomSheet)
        popover.configuration.animation = .slide(.bottom, duration: 0.05)
        let first = expectation(description: "first dismissal callback")
        let second = expectation(description: "second dismissal callback")
        var dismissals = 0
        popover.notificationDismissComplete = { dismissals += 1 }
        XCTAssertTrue(popover.show(from: presenter))
        popover.hidden { first.fulfill() }
        popover.hidden { second.fulfill() }
        await fulfillment(of: [first, second], timeout: 3)
        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(popover.presentationState, .hidden)
        XCTAssertTrue(presenter.children.isEmpty)
    }

    @MainActor
    func testBackdropVetoAndOverflow() throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = BonePopoverView(configuration: .bottomSheet)
        popover.configuration.animation = .none
        popover.preferredContentSize = CGSize(width: 400, height: 2000)
        popover.shouldDismiss = { _ in false }
        XCTAssertTrue(popover.show(from: presenter))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        XCTAssertTrue(host.scrollView.isScrollEnabled)
        XCTAssertGreaterThan(host.scrollView.contentSize.height, host.scrollView.bounds.height)
        host.backdrop.sendActions(for: .touchUpInside)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.shouldDismiss = nil
        host.backdrop.sendActions(for: .touchUpInside)
        XCTAssertEqual(popover.presentationState, .hidden)
    }

    @MainActor
    func testLiveRegionChangesAndStyleSwitchKeepContent() throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = BoneAlertView(title: "Title", message: "Message") {}
        popover.configuration.animation = .none
        var folded = false
        popover.reservedRegionProvider = { view in
            folded ? [CGRect(x: view.bounds.midX - 10, y: 0, width: 20, height: view.bounds.height)] : []
        }
        XCTAssertTrue(popover.show(from: presenter))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        let original = host.panelFrame
        folded = true
        popover.invalidatePopoverLayout()
        host.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(host.panelFrame.minX, host.bounds.midX + 10)
        XCTAssertNotEqual(host.panelFrame, original)
        popover.configuration.appearance = .liquidGlass
        host.layoutIfNeeded()
        XCTAssertTrue(popover.titleLabel.isDescendant(of: host))
        XCTAssertTrue(popover.baseView.backgroundColor == .clear)
        folded = false
        popover.invalidatePopoverLayout()
        host.layoutIfNeeded()
        XCTAssertEqual(host.panelFrame, original)
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testRemovalOfHostCleansUpAndReleasesPopover() {
        weak var weakPopover: BonePopoverView?
        autoreleasepool {
            let (window, presenter) = makeHost()
            var popover: BonePopoverView? = BonePopoverView(configuration: .centerDialog)
            popover?.configuration.animation = .none
            weakPopover = popover
            XCTAssertTrue(popover?.show(from: presenter) == true)
            popover = nil
            XCTAssertNotNil(weakPopover)
            presenter.view.removeFromSuperview()
            XCTAssertTrue(presenter.children.isEmpty)
            window.isHidden = true
        }
        XCTAssertNil(weakPopover)
    }

    @MainActor
    func testPresetActionRunsAfterRemoval() {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        var invoked = false
        let alert = BoneAlertView(title: "Confirm", message: "Message") {
            XCTAssertTrue(presenter.children.isEmpty)
            invoked = true
        }
        alert.configuration.animation = .none
        XCTAssertTrue(alert.show(from: presenter))
        alert.confirmButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(invoked)
    }
}
