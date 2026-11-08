import XCTest
@testable import BonePopoverKit

@MainActor
private final class LifecyclePopover: BonePopoverView {
    var dismissOnAppear = false
    var events: [String] = []
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if dismissOnAppear { dismissPopover(animated: false) }
    }
    override func willMove(toParent parent: UIViewController?) {
        if parent == nil { events.append("willRemove") }
        super.willMove(toParent: parent)
    }
    override func viewWillDisappear(_ animated: Bool) {
        events.append("willDisappear")
        super.viewWillDisappear(animated)
    }
    override func preferredPopoverSize(fitting availableSize: CGSize) -> CGSize {
        CGSize(width: 220, height: 100)
    }
}

@MainActor
private final class PanStub: UIPanGestureRecognizer {
    var simulatedState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { simulatedState }
        set { simulatedState = newValue }
    }
    override func translation(in view: UIView?) -> CGPoint { CGPoint(x: 0, y: 20) }
    override func velocity(in view: UIView?) -> CGPoint { .zero }
}

final class PopoverRegressionTests: XCTestCase {
    @MainActor
    private func makeHost() -> (UIWindow, UIViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 900))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.isHidden = false
        presenter.view.frame = window.bounds
        return (window, presenter)
    }

    @MainActor
    func testViewDidAppearCanDismissWithoutResurrectingState() {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = LifecyclePopover(configuration: .centerDialog)
        popover.dismissOnAppear = true
        var didShow = false
        popover.onDidShow = { didShow = true }
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        XCTAssertEqual(popover.presentationState, .hidden)
        XCTAssertNil(popover.parent)
        XCTAssertFalse(didShow)
        popover.dismissOnAppear = false
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testRemovalBeginsBeforeDisappearanceCallbacks() {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = LifecyclePopover(configuration: .centerDialog)
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        popover.events.removeAll()
        popover.dismissPopover(animated: false)
        XCTAssertEqual(Array(popover.events.prefix(2)), ["willRemove", "willDisappear"])
    }

    @MainActor
    func testContentWidthUsesSubclassMeasurement() throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = LifecyclePopover(configuration: .centerDialog)
        popover.configuration.layout.width = .content
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        XCTAssertEqual(host.panelFrame.width, 220)
        XCTAssertEqual(popover.view.bounds.width, 220)
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testCancelledPanCannotOverrideProgrammaticDismissal() async throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = BonePopoverView(configuration: .bottomSheet)
        popover.configuration.animation = .slide(.bottom, duration: 0.05)
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        let pan = PanStub()
        pan.simulatedState = .began
        host.handlePan(pan)
        let dismissed = expectation(description: "programmatic dismissal survives pan cancellation")
        popover.dismissPopover { dismissed.fulfill() }
        pan.simulatedState = .cancelled
        host.handlePan(pan)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(popover.presentationState, .hidden)
        XCTAssertTrue(presenter.children.isEmpty)
    }

    @MainActor
    func testRegionChangeRetargetsDismissalWithoutChangingBounds() async throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let popover = BonePopoverView(configuration: .bottomSheet)
        popover.configuration.animation = .slide(.bottom, duration: 0.1)
        popover.configuration.respectsReduceMotion = false
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        let originalBounds = host.bounds
        let dismissed = expectation(description: "retargeted dismissal completes")
        popover.dismissPopover { dismissed.fulfill() }
        popover.reservedRegionProvider = { view in
            [CGRect(x: 0, y: view.bounds.midY, width: view.bounds.width, height: view.bounds.height / 2)]
        }
        host.layoutIfNeeded()
        XCTAssertEqual(host.bounds, originalBounds)
        XCTAssertGreaterThanOrEqual(host.panelFrame.minY + host.surface.transform.ty, host.bounds.maxY - 0.5)
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(popover.presentationState, .hidden)
    }

    func testAnchorCanChooseSmallerPane() {
        var layout = PopoverLayout()
        layout.anchorPoint = CGPoint(x: 100, y: 300)
        layout.width = .content
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 1000, height: 700),
            excludedFrames: [CGRect(x: 300, y: 0, width: 20, height: 700)])
        let frame = PopoverLayoutEngine.frame(in: context, layout: layout, contentSize: CGSize(width: 220, height: 100))
        XCTAssertEqual(frame.width, 220)
        XCTAssertLessThanOrEqual(frame.maxX, 300)
    }
}
