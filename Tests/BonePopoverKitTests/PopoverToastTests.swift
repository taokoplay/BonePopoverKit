import XCTest
@testable import BonePopoverKit

final class PopoverToastTests: XCTestCase {
    @MainActor
    private func makeHost(size: CGSize = CGSize(width: 800, height: 900)) -> (UIWindow, UIViewController) {
        let presenter = UIViewController()
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = presenter
        window.isHidden = false
        presenter.loadViewIfNeeded()
        presenter.view.frame = window.bounds
        return (window, presenter)
    }

    @MainActor
    private func mount(_ toast: BoneToastView, in presenter: UIViewController) throws -> PopoverHostView {
        toast.configuration.animation = .none
        XCTAssertTrue(toast.show(from: presenter))
        return try XCTUnwrap(toast.presentationHost)
    }

    @MainActor
    func testThreeStylesHaveCorrectGeometryAndOutsideTouchesPassThrough() throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: 400, width: 100, height: 44)
        presenter.view.addSubview(button)
        for style in [BoneToastView.Style.top, .bottom, .center] {
            let toast = BoneToastView(message: "已保存", style: style,
                                      image: UIImage(systemName: "checkmark.circle.fill"), duration: 0)
            let host = try mount(toast, in: presenter)
            let area = PopoverLayoutEngine.availableFrame(
                in: PopoverLayoutContext(bounds: host.bounds, safeAreaInsets: host.safeAreaInsets),
                layout: toast.configuration.layout)
            switch style {
            case .top:
                XCTAssertEqual(host.panelFrame.minY, area.minY, accuracy: 0.5)
                XCTAssertEqual(host.panelFrame.width, 560, accuracy: 0.5)
            case .bottom:
                XCTAssertEqual(host.panelFrame.maxY, area.maxY, accuracy: 0.5)
                XCTAssertEqual(host.panelFrame.width, 560, accuracy: 0.5)
            case .center:
                XCTAssertEqual(host.panelFrame.midY, area.midY, accuracy: 0.5)
                XCTAssertEqual(host.panelFrame.width, 160, accuracy: 0.5)
                XCTAssertEqual(host.panelFrame.width, host.panelFrame.height, accuracy: 0.5)
            }
            let icon = toast.imageView.convert(toast.imageView.bounds, to: toast.baseView)
            let text = toast.messageLabel.convert(toast.messageLabel.bounds, to: toast.baseView)
            if style == .center {
                XCTAssertEqual(text.minY - icon.maxY, 12, accuracy: 0.5)
                XCTAssertEqual(icon.midX, toast.baseView.bounds.midX, accuracy: 0.5)
                XCTAssertEqual((icon.minY + text.maxY) / 2, toast.baseView.bounds.midY, accuracy: 0.5)
            } else {
                XCTAssertEqual(text.minX - icon.maxX, 12, accuracy: 0.5)
                XCTAssertEqual(icon.midY, text.midY, accuracy: 0.5)
            }
            XCTAssertEqual(host.backdropDimmingView.alpha, 0)
            XCTAssertFalse(host.accessibilityViewIsModal)
            XCTAssertTrue(presenter.view.hitTest(button.center, with: nil) === button)
            XCTAssertEqual(toast.presentationState, .presented)
            toast.dismissPopover(animated: false)
        }
    }

    @MainActor
    func testMessageImageAndTypographyUpdatesRemeasureTheBar() throws {
        let (window, presenter) = makeHost(size: CGSize(width: 360, height: 800))
        defer { window.isHidden = true }
        let toast = BoneToastView(message: "已保存", style: .bottom, duration: 0)
        let host = try mount(toast, in: presenter)
        defer { toast.dismissPopover(animated: false) }
        let shortHeight = host.panelFrame.height
        XCTAssertFalse(toast.imageView.isHidden)
        XCTAssertNotNil(toast.imageView.image)
        XCTAssertEqual(toast.messageLabel.convert(.zero, to: toast.baseView).x, 56, accuracy: 0.5)
        toast.message = String(repeating: "更改已保存，可以继续操作。", count: 5)
        toast.image = UIImage(systemName: "checkmark")
        toast.configuration.contentStyle.messageFont = .systemFont(ofSize: 24, weight: .bold)
        toast.configuration.contentStyle.adjustsFontForContentSizeCategory = false
        toast.configuration.contentStyle.messageColor = .systemRed
        host.layoutIfNeeded()
        XCTAssertGreaterThan(host.panelFrame.height, shortHeight + 40)
        XCTAssertEqual(toast.messageLabel.font.pointSize, 24)
        XCTAssertEqual(toast.messageLabel.textColor, .systemRed)
        XCTAssertFalse(toast.imageView.isHidden)
        XCTAssertEqual(toast.messageLabel.text, toast.message)
        toast.message = "已保存"
        toast.image = nil
        host.layoutIfNeeded()
        XCTAssertFalse(toast.imageView.isHidden)
        XCTAssertNil(toast.image)
        XCTAssertEqual(toast.imageView.tintColor, .systemBlue)
        XCTAssertEqual(toast.messageLabel.convert(.zero, to: toast.baseView).x, 56, accuracy: 0.5)
        XCTAssertLessThan(host.panelFrame.height, shortHeight + 40)
    }

    @MainActor
    func testCenterRemainsSquareWithLongContentAndSmallAvailableRegions() throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let toast = BoneToastView(message: String(repeating: "长内容与大字号仍可滚动阅读。", count: 40),
                                  style: .center, image: UIImage(systemName: "checkmark"), duration: 0)
        let host = try mount(toast, in: presenter)
        defer { toast.dismissPopover(animated: false) }
        XCTAssertEqual(host.panelFrame.size, CGSize(width: 280, height: 280))
        let scroll = try XCTUnwrap(toast.baseView.subviews.first as? UIScrollView)
        scroll.layoutIfNeeded()
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        scroll.contentOffset.y = scroll.contentSize.height - scroll.bounds.height
        scroll.layoutIfNeeded()
        let textEnd = toast.messageLabel.convert(CGPoint(x: 0, y: toast.messageLabel.bounds.maxY), to: toast.baseView)
        XCTAssertEqual(textEnd.y, toast.baseView.bounds.maxY - 24, accuracy: 1)
        toast.reservedRegionProvider = { view in
            [CGRect(x: 180, y: 0, width: view.bounds.width - 180, height: view.bounds.height),
             CGRect(x: 0, y: 140, width: view.bounds.width, height: view.bounds.height - 140)]
        }
        host.layoutIfNeeded()
        XCTAssertLessThanOrEqual(host.panelFrame.width, 156)
        XCTAssertLessThanOrEqual(host.panelFrame.height, 116)
        XCTAssertEqual(host.panelFrame.width, host.panelFrame.height, accuracy: 0.5)
        XCTAssertTrue(host.panelFrame.intersection(CGRect(x: 180, y: 0, width: 620, height: 900)).isEmpty)
    }

    @MainActor
    func testAutomaticDismissalStartsAfterEntryAndKeepsClientCallbacks() async throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let toast = BoneToastView(message: "已保存", style: .top, duration: 0.08)
        toast.configuration.animation = .slide(.top, duration: 0.3)
        let shown = expectation(description: "client show callback")
        let dismissed = expectation(description: "client dismissal callback")
        var shows = 0
        var dismissals = 0
        toast.onDidShow = { shows += 1; shown.fulfill() }
        toast.notificationDismissComplete = { dismissals += 1; dismissed.fulfill() }
        XCTAssertTrue(toast.show(from: presenter))
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertTrue(toast.isPresented)
        await fulfillment(of: [shown, dismissed], timeout: 5, enforceOrder: true)
        XCTAssertEqual(shows, 1)
        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(toast.presentationState, .hidden)
        XCTAssertTrue(presenter.children.isEmpty)
    }

    @MainActor
    func testCancelledTimersCannotDismissAReusedToastAndDurationCanRestart() async throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let toast = BoneToastView(message: "已保存", duration: 0.05)
        _ = try mount(toast, in: presenter)
        let firstIdentifier = toast.presentationIdentifier
        toast.dismissPopover(animated: false)
        toast.duration = 0.3
        XCTAssertTrue(toast.show(from: presenter))
        XCTAssertNotEqual(toast.presentationIdentifier, firstIdentifier)
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(toast.presentationState, .presented)
        toast.duration = 0
        try await Task.sleep(nanoseconds: 320_000_000)
        XCTAssertEqual(toast.presentationState, .presented)
        let dismissed = expectation(description: "new timer dismisses reused toast")
        toast.notificationDismissComplete = { dismissed.fulfill() }
        toast.duration = 0.05
        await fulfillment(of: [dismissed], timeout: 2)
        XCTAssertEqual(toast.presentationState, .hidden)
    }

    @MainActor
    func testDisabledAndVeryLargeDurationsStayVisibleUntilManuallyDismissed() async throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let durations: [TimeInterval] = [0, -1, .nan, .infinity, .greatestFiniteMagnitude]
        let toasts = try durations.map { duration -> BoneToastView in
            let toast = BoneToastView(message: "手动关闭", duration: duration)
            _ = try mount(toast, in: presenter)
            return toast
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        for toast in toasts {
            XCTAssertEqual(toast.presentationState, .presented)
            toast.dismissPopover(animated: false)
        }
        XCTAssertTrue(presenter.children.isEmpty)
    }

    @MainActor
    func testAllTypesRenderAnIndicatorInEveryLayout() throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        for style in [BoneToastView.Style.top, .bottom, .center] {
            for type in BoneToastView.ToastType.allCases {
                let toast = BoneToastView(message: "状态提示", type: type, style: style, duration: 0)
                let host = try mount(toast, in: presenter)
                if type == .loading {
                    XCTAssertTrue(toast.loadingIndicator.isAnimating)
                    XCTAssertTrue(toast.imageView.isHidden)
                    let spinner = toast.loadingIndicator.convert(toast.loadingIndicator.bounds, to: toast.baseView)
                    XCTAssertGreaterThanOrEqual(spinner.width, 20)
                    XCTAssertTrue(toast.baseView.bounds.contains(spinner))
                } else {
                    XCTAssertFalse(toast.loadingIndicator.isAnimating)
                    XCTAssertFalse(toast.imageView.isHidden)
                    XCTAssertNotNil(toast.imageView.image)
                    let expected: UIColor = switch type {
                    case .success: .systemGreen
                    case .failure: .systemRed
                    default: .systemBlue
                    }
                    XCTAssertEqual(toast.imageView.tintColor, expected)
                }
                if style == .center {
                    XCTAssertEqual(host.panelFrame.width, host.panelFrame.height, accuracy: 0.5)
                }
                toast.dismissPopover(animated: false)
                XCTAssertFalse(toast.loadingIndicator.isAnimating)
            }
        }
    }

    @MainActor
    func testLoadingTransitionsCustomImagesAndReuse() throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let toast = BoneToastView(message: "加载中", type: .loading, style: .center, duration: 0)
        toast.loadViewIfNeeded()
        XCTAssertFalse(toast.loadingIndicator.isAnimating)
        let host = try mount(toast, in: presenter)
        let frame = host.panelFrame
        XCTAssertTrue(toast.loadingIndicator.isAnimating)
        toast.message = "保存成功"
        toast.type = .success
        host.layoutIfNeeded()
        XCTAssertFalse(toast.loadingIndicator.isAnimating)
        XCTAssertFalse(toast.imageView.isHidden)
        XCTAssertEqual(toast.messageLabel.accessibilityValue, "成功")
        XCTAssertEqual(host.panelFrame, frame)
        let custom = try XCTUnwrap(UIImage(systemName: "star.fill"))
        toast.image = custom
        XCTAssertTrue(toast.imageView.image === custom)
        toast.type = .loading
        XCTAssertTrue(toast.imageView.isHidden)
        XCTAssertTrue(toast.loadingIndicator.isAnimating)
        toast.type = .failure
        XCTAssertFalse(toast.loadingIndicator.isAnimating)
        XCTAssertTrue(toast.imageView.image === custom)
        toast.image = nil
        XCTAssertNotNil(toast.imageView.image)
        XCTAssertEqual(toast.imageView.tintColor, .systemRed)
        toast.type = .loading
        toast.dismissPopover(animated: false)
        XCTAssertFalse(toast.loadingIndicator.isAnimating)
        XCTAssertTrue(toast.show(from: presenter))
        XCTAssertTrue(toast.loadingIndicator.isAnimating)
        presenter.view.removeFromSuperview()
        XCTAssertEqual(toast.presentationState, .hidden)
        XCTAssertFalse(toast.loadingIndicator.isAnimating)
    }

    @MainActor
    func testEveryTypeAutomaticallyDismissesAfterTheDefaultTwoSeconds() async throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let toasts = BoneToastView.ToastType.allCases.map { BoneToastView(message: "默认时长", type: $0) }
        let completed = toasts.enumerated().map { index, toast in
            let finished = expectation(description: "type \(index) dismissed")
            toast.notificationDismissComplete = { finished.fulfill() }
            return finished
        }
        let started = Date()
        for toast in toasts {
            XCTAssertEqual(toast.duration, 2)
            _ = try mount(toast, in: presenter)
        }
        await fulfillment(of: completed, timeout: 4)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 1.8)
        XCTAssertTrue(toasts.allSatisfy { $0.presentationState == .hidden && !$0.loadingIndicator.isAnimating })
        XCTAssertTrue(presenter.children.isEmpty)
    }

    @MainActor
    func testChangingTypeRestartsTheCurrentDuration() async throws {
        let (window, presenter) = makeHost()
        defer { window.isHidden = true }
        let toast = BoneToastView(message: "加载中", type: .loading, duration: 0.35)
        _ = try mount(toast, in: presenter)
        try await Task.sleep(nanoseconds: 200_000_000)
        toast.message = "已完成"
        toast.type = .success
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(toast.presentationState, .presented)
        XCTAssertFalse(toast.loadingIndicator.isAnimating)
        let dismissed = expectation(description: "updated type uses custom duration")
        toast.notificationDismissComplete = { dismissed.fulfill() }
        toast.duration = 0.05
        await fulfillment(of: [dismissed], timeout: 2)
        XCTAssertEqual(toast.presentationState, .hidden)
    }

    @MainActor
    func testRemovalCancelsTimerAndDoesNotRetainToast() {
        weak var retainedToast: BoneToastView?
        autoreleasepool {
            let (window, presenter) = makeHost()
            let toast = BoneToastView(message: "已保存", duration: 60)
            toast.configuration.animation = .none
            XCTAssertTrue(toast.show(from: presenter))
            retainedToast = toast
            presenter.view.removeFromSuperview()
            XCTAssertEqual(toast.presentationState, .hidden)
            window.isHidden = true
        }
        XCTAssertNil(retainedToast)
    }
}
