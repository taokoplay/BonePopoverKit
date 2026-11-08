import XCTest
@testable import BonePopoverKit

@MainActor
private final class InteractionPan: UIPanGestureRecognizer {
    var phase: UIGestureRecognizer.State = .possible
    var travel = CGPoint.zero
    var speed = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { phase }
        set { phase = newValue }
    }
    override func translation(in view: UIView?) -> CGPoint { travel }
    override func velocity(in view: UIView?) -> CGPoint { speed }
}

final class PopoverInteractionTests: XCTestCase {
    @MainActor
    private func present(_ configure: (BonePopoverView) -> Void = { _ in }) throws
        -> (UIWindow, UIViewController, BonePopoverView, PopoverHostView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.isHidden = false
        presenter.view.frame = window.bounds
        let popover = BonePopoverView(configuration: .centerDialog)
        popover.preferredContentSize = CGSize(width: 300, height: 240)
        popover.configuration.animation = .none
        popover.configuration.respectsReduceMotion = false
        configure(popover)
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        return (window, presenter, popover, host)
    }

    @MainActor
    private func drag(_ host: PopoverHostView, direction: PopoverSwipeDirection,
                      distance: CGFloat, end: UIGestureRecognizer.State = .ended,
                      velocity: CGFloat = 0) {
        let gesture = InteractionPan()
        gesture.speed = CGPoint(x: direction.vector.x * 100, y: direction.vector.y * 100)
        gesture.phase = .began
        host.handlePan(gesture)
        gesture.travel = CGPoint(x: direction.vector.x * distance, y: direction.vector.y * distance)
        gesture.speed = .zero
        gesture.phase = .changed
        host.handlePan(gesture)
        gesture.speed = CGPoint(x: direction.vector.x * velocity, y: direction.vector.y * velocity)
        gesture.phase = end
        host.handlePan(gesture)
    }

    @MainActor
    func testHiddenBackdropStillReceivesOutsideTap() throws {
        for hidesUsingFlag in [false, true] {
            let (window, _, popover, host) = try present {
                if hidesUsingFlag { $0.configuration.showsBackdrop = false }
                else { $0.configuration.appearance.backdropOpacity = 0 }
            }
            defer { window.isHidden = true }
            XCTAssertEqual(host.backdropDimmingView.alpha, 0)
            XCTAssertEqual(host.backdrop.alpha, 1)
            XCTAssertTrue(host.hitTest(CGPoint(x: 2, y: 2), with: nil) === host.backdrop)
            host.backdrop.sendActions(for: .touchUpInside)
            XCTAssertEqual(popover.presentationState, .hidden)
        }
    }

    @MainActor
    func testOutsideTapDisabledAndVetoRemainIndependentOfBackdrop() throws {
        let (window, _, popover, host) = try present {
            $0.configuration.showsBackdrop = false
            $0.configuration.dismissOnBackdropTap = false
        }
        defer { window.isHidden = true }
        host.backdrop.sendActions(for: .touchUpInside)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.configuration.dismissOnBackdropTap = true
        var attempts = 0
        popover.shouldDismiss = { reason in
            XCTAssertEqual(reason, .penetration)
            attempts += 1
            return false
        }
        host.backdrop.sendActions(for: .touchUpInside)
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.dismissPopover(animated: false)
        XCTAssertEqual(popover.presentationState, .hidden, "Programmatic cleanup bypasses the user-interaction veto")
    }

    @MainActor
    func testPassthroughRoutesHitsWithoutDismissingDuringHitTesting() throws {
        let (window, presenter, popover, host) = try present {
            $0.configuration.allowsEventPenetration = true
            $0.configuration.autoHideWhenPenetrated = true
            $0.configuration.dismissOnBackdropTap = false
        }
        defer { window.isHidden = true }
        let button = UIButton(type: .system)
        button.frame = presenter.view.bounds
        presenter.view.insertSubview(button, at: 0)
        let outside = CGPoint(x: 2, y: 2)
        for _ in 0..<5 {
            XCTAssertTrue(presenter.view.hitTest(outside, with: nil) === button)
            XCTAssertEqual(popover.presentationState, .presented)
        }
        let inside = CGPoint(x: host.panelFrame.midX, y: host.panelFrame.midY)
        XCTAssertNotNil(host.hitTest(inside, with: nil))
        XCTAssertFalse(host.accessibilityViewIsModal)
        popover.configuration.allowsEventPenetration = false
        XCTAssertTrue(presenter.view.hitTest(outside, with: nil) === host.backdrop)
        XCTAssertTrue(host.accessibilityViewIsModal)
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testPassthroughObserverIsRemovedWhenDisabledOrDismissed() throws {
        let (window, _, popover, _) = try present()
        defer { window.isHidden = true }
        let original = Set((window.gestureRecognizers ?? []).map(ObjectIdentifier.init))
        popover.configuration.allowsEventPenetration = true
        popover.configuration.autoHideWhenPenetrated = true
        let observer = try XCTUnwrap(window.gestureRecognizers?.first { !original.contains(ObjectIdentifier($0)) })
        XCTAssertTrue(observer.view === window)
        popover.configuration.autoHideWhenPenetrated = false
        XCTAssertNil(observer.view)
        popover.configuration.autoHideWhenPenetrated = true
        XCTAssertTrue(observer.view === window)
        popover.dismissPopover(animated: false)
        XCTAssertNil(observer.view)
    }

    func testAutomaticDefaultsAndExplicitPhysicalDirections() {
        XCTAssertEqual(PopoverSwipeDirection.automatic.resolved(for: .bottom, isRightToLeft: false), .down)
        XCTAssertEqual(PopoverSwipeDirection.automatic.resolved(for: .top, isRightToLeft: false), .up)
        XCTAssertEqual(PopoverSwipeDirection.automatic.resolved(for: .leading, isRightToLeft: false), .left)
        XCTAssertEqual(PopoverSwipeDirection.automatic.resolved(for: .trailing, isRightToLeft: true), .left)
        XCTAssertEqual(PopoverSwipeDirection.automatic.resolved(for: .center, isRightToLeft: false), .all)
        XCTAssertEqual(PopoverSwipeDirection.left.resolved(for: .center, isRightToLeft: true), .left)
        XCTAssertEqual(PopoverSwipeDirection.none.resolved(for: .bottom, isRightToLeft: false), .none)
        XCTAssertNil(PopoverSwipeDirection.dominant(in: CGPoint(x: 100, y: 20), allowed: .vertical))
    }

    @MainActor
    func testCenterCanDismissInEachDirectionAndExitOnThatSide() throws {
        for direction in [PopoverSwipeDirection.left, .right, .up, .down] {
            let (window, _, popover, host) = try present {
                $0.configuration.allowsDragToDismiss = true
                $0.configuration.allowedSwipeDirections = .all
            }
            defer { window.isHidden = true }
            var notifications = 0
            popover.notificationDismissComplete = { notifications += 1 }
            drag(host, direction: direction, distance: 120)
            XCTAssertEqual(popover.presentationState, .hidden)
            XCTAssertEqual(notifications, 1)
            let final = host.panelFrame.applying(host.surface.transform)
            switch direction {
            case .left: XCTAssertLessThanOrEqual(final.maxX, host.bounds.minX)
            case .right: XCTAssertGreaterThanOrEqual(final.minX, host.bounds.maxX)
            case .up: XCTAssertLessThanOrEqual(final.maxY, host.bounds.minY)
            default: XCTAssertGreaterThanOrEqual(final.minY, host.bounds.maxY)
            }
        }
    }

    @MainActor
    func testExplicitDirectionCombinationRejectsOthers() throws {
        let (window, _, popover, host) = try present {
            $0.configuration.allowsDragToDismiss = true
            $0.configuration.allowedSwipeDirections = [.left, .up]
        }
        defer { window.isHidden = true }
        drag(host, direction: .right, distance: 200)
        drag(host, direction: .down, distance: 200)
        XCTAssertEqual(popover.presentationState, .presented)
        XCTAssertEqual(host.surface.transform, .identity)
        drag(host, direction: .left, distance: 120)
        XCTAssertEqual(popover.presentationState, .hidden)
    }

    @MainActor
    func testDisabledDragAndEmptyDirectionsCannotDismissCenter() throws {
        let (window, _, popover, host) = try present()
        defer { window.isHidden = true }
        drag(host, direction: .down, distance: 200)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.configuration.allowsDragToDismiss = true
        popover.configuration.allowedSwipeDirections = .none
        drag(host, direction: .down, distance: 200)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testThresholdCancellationReversalAndVetoSnapBack() throws {
        let (window, _, popover, host) = try present {
            $0.configuration.allowsDragToDismiss = true
            $0.configuration.swipeThreshold = 150
        }
        defer { window.isHidden = true }
        drag(host, direction: .down, distance: 120)
        XCTAssertEqual(popover.presentationState, .presented)
        XCTAssertEqual(host.surface.transform, .identity)
        drag(host, direction: .up, distance: 200, end: .cancelled)
        XCTAssertEqual(popover.presentationState, .presented)
        XCTAssertEqual(host.surface.transform, .identity)
        drag(host, direction: .left, distance: 200, velocity: -500)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.configuration.swipeThreshold = 50
        popover.shouldDismiss = { _ in false }
        drag(host, direction: .right, distance: 80)
        XCTAssertEqual(popover.presentationState, .presented)
        XCTAssertEqual(host.surface.transform, .identity)
        popover.shouldDismiss = nil
        drag(host, direction: .right, distance: 80)
        XCTAssertEqual(popover.presentationState, .hidden)
    }

    @MainActor
    func testFastFlickUsesConfiguredProjectedThreshold() throws {
        let (window, _, popover, host) = try present {
            $0.configuration.allowsDragToDismiss = true
            $0.configuration.swipeThreshold = 150
        }
        defer { window.isHidden = true }
        drag(host, direction: .up, distance: 30, velocity: 1000)
        XCTAssertEqual(popover.presentationState, .hidden)
    }

    @MainActor
    func testChangingDragConfigurationCancelsActiveDrag() throws {
        let (window, _, popover, host) = try present { $0.configuration.allowsDragToDismiss = true }
        defer { window.isHidden = true }
        let gesture = InteractionPan()
        gesture.speed = CGPoint(x: -100, y: 0)
        gesture.phase = .began
        host.handlePan(gesture)
        gesture.travel = CGPoint(x: -60, y: 0)
        gesture.phase = .changed
        host.handlePan(gesture)
        XCTAssertEqual(host.surface.transform.tx, -60)
        popover.configuration.allowsDragToDismiss = false
        gesture.phase = .ended
        host.handlePan(gesture)
        XCTAssertEqual(host.surface.transform, .identity)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testSwipeDoesNotReplaceConfiguredAnimationAcrossReuse() throws {
        let (window, presenter, popover, host) = try present {
            $0.configuration.allowsDragToDismiss = true
            $0.configuration.animation = PopoverAnimation(duration: 0) { _, _, _ in
                PopoverVisualState(transform: .init(scaleX: 0.7, y: 0.7), opacity: 0)
            }
        }
        defer { window.isHidden = true }
        drag(host, direction: .left, distance: 120)
        let hidden = popover.configuration.animation.hiddenState(.zero, .zero, false)
        XCTAssertEqual(hidden.transform.a, 0.7)
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testScrollViewsKeepGesturesUntilTheCorrespondingBoundary() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        scroll.contentSize = CGSize(width: 600, height: 800)
        scroll.contentInset = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        scroll.contentOffset = CGPoint(x: 100, y: 100)
        for direction in [PopoverSwipeDirection.left, .right, .up, .down] {
            XCTAssertFalse(direction.canTakeOver(scroll))
        }
        scroll.contentOffset = CGPoint(x: -20, y: -10)
        XCTAssertTrue(PopoverSwipeDirection.right.canTakeOver(scroll))
        XCTAssertTrue(PopoverSwipeDirection.down.canTakeOver(scroll))
        XCTAssertFalse(PopoverSwipeDirection.left.canTakeOver(scroll))
        scroll.contentOffset = CGPoint(x: 440, y: 630)
        XCTAssertTrue(PopoverSwipeDirection.left.canTakeOver(scroll))
        XCTAssertTrue(PopoverSwipeDirection.up.canTakeOver(scroll))
    }

    @MainActor
    func testProgrammaticCloseInsideSwipeVetoCannotBeReplacedBySnapBack() async throws {
        let (window, _, popover, host) = try present {
            $0.configuration.allowsDragToDismiss = true
            $0.configuration.animation.duration = 0.05
        }
        defer { window.isHidden = true }
        let finished = expectation(description: "programmatic close from swipe veto")
        popover.shouldDismiss = { [weak popover] _ in
            popover?.dismissPopover { finished.fulfill() }
            return false
        }
        drag(host, direction: .down, distance: 160)
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(popover.presentationState, .hidden)
        XCTAssertNil(popover.parent)
    }

    @MainActor
    func testChangingBackdropDuringAnimationRetargetsItsFinalOpacity() async throws {
        let (window, _, popover, host) = try present { $0.configuration.animation.duration = 0.05 }
        defer { window.isHidden = true }
        for shown in [false, true] {
            let completed = expectation(description: "retargeted backdrop \(shown)")
            host.transition(visible: true, animated: true) { completed.fulfill() }
            popover.configuration.showsBackdrop = shown
            await fulfillment(of: [completed], timeout: 3)
            XCTAssertEqual(host.backdropDimmingView.alpha,
                           shown ? popover.configuration.appearance.backdropOpacity : 0, accuracy: 0.001)
        }
        popover.dismissPopover(animated: false)
    }
}
