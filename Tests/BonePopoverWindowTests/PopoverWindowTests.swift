import XCTest
@testable import BonePopoverKit

@MainActor
private final class LoadingWindowPopover: BonePopoverView {
    var duringLoad: (() -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        duringLoad?()
    }
}

@MainActor
private final class RecordingWindowPopover: BonePopoverView {
    var reasons: [PopoverDismissReason] = []
    override func notificationHidden(type: CLPopoverDismissType) { reasons.append(type) }
}

final class PopoverWindowTests: XCTestCase {
    @MainActor
    private func source() throws -> (UIWindowScene, UIWindow) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        window.rootViewController?.view.layoutIfNeeded()
        return (scene, window)
    }

    @MainActor
    func testDefaultsAndExplicitWindowPresentationSnapshot() throws {
        let (scene, source) = try source()
        defer { source.isHidden = true }
        let popover = BoneAlertView(title: "窗口", message: "内容") {}
        XCTAssertEqual(popover.configuration.window.level, .alert - 1)
        XCTAssertEqual(popover.configuration.window.stacking, .aboveManagedPopovers)
        XCTAssertEqual(popover.configuration.window.keyPolicy, .takeAndRestore)
        XCTAssertEqual(popover.configuration.window.container, .plain)
        XCTAssertTrue(popover.show(over: source, animated: false))
        let session = try XCTUnwrap(popover.windowSession)
        XCTAssertTrue(popover.view.window === session.window)
        XCTAssertTrue(session.window.windowScene === scene)
        XCTAssertTrue(session.window.isKeyWindow)
        XCTAssertFalse(popover.show(over: source, animated: false))
        XCTAssertFalse(popover.show(from: source.rootViewController!, animated: false))
        let level = session.window.windowLevel
        popover.configuration.window.level = .normal
        popover.configuration.window.container = .navigation
        XCTAssertEqual(session.window.windowLevel, level)
        XCTAssertNil(popover.navigationController)
        popover.configuration.contentStyle.titleFont = .boldSystemFont(ofSize: 25)
        XCTAssertEqual(popover.titleLabel.font.pointSize, 25, accuracy: 0.01)
        popover.dismissPopover(animated: false)
        XCTAssertTrue(source.isKeyWindow)
        XCTAssertTrue(session.window.isHidden)
        XCTAssertNil(session.window.rootViewController)
        XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
        XCTAssertTrue(popover.show(over: source, animated: false))
        XCTAssertNotNil(popover.navigationController)
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testInvalidLevelAndMissingContextLeaveNoWindowOrLoadedContent() throws {
        let (scene, source) = try source()
        defer { source.isHidden = true }
        let popover = BonePopoverView(configuration: .centerDialog)
        for raw in [CGFloat.nan, .infinity, -.infinity] {
            popover.configuration.window.level = UIWindow.Level(rawValue: raw)
            XCTAssertFalse(popover.show(over: source, animated: false))
            XCTAssertFalse(popover.isViewLoaded)
            XCTAssertEqual(popover.presentationState, .hidden)
            XCTAssertTrue(source.isKeyWindow)
            XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
        }
        popover.configuration.window.level = .normal
        let detached = UIWindow(frame: source.bounds)
        XCTAssertFalse(popover.show(over: detached, animated: false))
        source.isHidden = true
        XCTAssertFalse(popover.show(over: source, animated: false))
    }

    @MainActor
    func testLoadingCancellationAndReentrantShowRollBack() throws {
        let (scene, source) = try source()
        defer { source.isHidden = true }
        let popover = LoadingWindowPopover(configuration: .centerDialog)
        var shows = 0
        var dismissals = 0
        popover.onDidShow = { shows += 1 }
        popover.notificationDismissComplete = { dismissals += 1 }
        popover.duringLoad = { [weak popover] in
            XCTAssertFalse(popover?.show(over: source, animated: false) ?? true)
            popover?.dismissPopover(animated: false)
        }
        XCTAssertFalse(popover.show(over: source, animated: false))
        XCTAssertEqual(popover.presentationState, .hidden)
        XCTAssertNil(popover.parent)
        XCTAssertEqual(shows, 0)
        XCTAssertEqual(dismissals, 1)
        XCTAssertTrue(source.isKeyWindow)
        XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
        popover.duringLoad = nil
        XCTAssertTrue(popover.show(over: source, animated: false))
        popover.dismissPopover(animated: false)
    }

    @MainActor
    func testStackingAndOutOfOrderClosureRestoreTheBusinessWindow() throws {
        let (scene, source) = try source()
        defer { source.isHidden = true }
        source.windowLevel = .alert + 5
        let first = BonePopoverView(configuration: .centerDialog)
        let second = BonePopoverView(configuration: .centerDialog)
        XCTAssertTrue(first.show(over: source, animated: false))
        let firstWindow = try XCTUnwrap(first.view.window)
        XCTAssertGreaterThan(firstWindow.windowLevel, source.windowLevel)
        XCTAssertTrue(second.show(in: scene, animated: false))
        let secondWindow = try XCTUnwrap(second.view.window)
        XCTAssertGreaterThan(secondWindow.windowLevel, firstWindow.windowLevel)
        first.dismissPopover(animated: false)
        XCTAssertTrue(secondWindow.isKeyWindow)
        second.dismissPopover(animated: false)
        XCTAssertTrue(source.isKeyWindow)
        XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
    }

    @MainActor
    func testFixedLayerAndPreservingKeyDoNotTakeInputOwnership() throws {
        let (_, source) = try source()
        defer { source.isHidden = true }
        let popover = BonePopoverView(configuration: .topBanner)
        popover.configuration.window.level = .normal + 50
        popover.configuration.window.stacking = .fixed
        popover.configuration.window.keyPolicy = .preserveCurrent
        XCTAssertTrue(popover.show(over: source, animated: false))
        XCTAssertEqual(popover.view.window?.windowLevel, .normal + 50)
        XCTAssertTrue(source.isKeyWindow)
        XCTAssertFalse(popover.view.window?.canBecomeKey ?? true)
        popover.dismissPopover(animated: false)
        XCTAssertTrue(source.isKeyWindow)
    }

    @MainActor
    func testUserKeySwitchIsNotOverriddenOnClose() throws {
        let (scene, source) = try source()
        let other = UIWindow(windowScene: scene)
        other.rootViewController = UIViewController()
        defer { source.isHidden = true; other.isHidden = true }
        let popover = BonePopoverView(configuration: .centerDialog)
        XCTAssertTrue(popover.show(over: source, animated: false))
        other.makeKeyAndVisible()
        XCTAssertTrue(other.isKeyWindow)
        popover.dismissPopover(animated: false)
        XCTAssertTrue(other.isKeyWindow)
    }

    @MainActor
    func testInputFocusAndSelectionReturnToOriginalField() throws {
        let (_, source) = try source()
        defer { source.isHidden = true }
        let field = UITextField(frame: CGRect(x: 20, y: 100, width: 240, height: 44))
        source.rootViewController?.view.addSubview(field)
        field.text = "原输入"
        XCTAssertTrue(field.becomeFirstResponder())
        let input = BoneAlertView(title: "输入", placeholder: "新名称") { _ in }
        XCTAssertTrue(input.show(over: source, animated: false))
        XCTAssertTrue(input.textField.isFirstResponder)
        input.dismissPopover(animated: false)
        XCTAssertTrue(source.isKeyWindow)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(field.text, "原输入")
    }

    @MainActor
    func testNavigationPushAndPopKeepWindowSessionAlive() throws {
        let (_, source) = try source()
        defer { source.isHidden = true }
        let popover = RecordingWindowPopover(configuration: .centerDialog)
        popover.configuration.window.container = .navigation
        XCTAssertTrue(popover.show(over: source, animated: false))
        let nav = try XCTUnwrap(popover.navigationController)
        let session = try XCTUnwrap(popover.windowSession)
        let detail = UIViewController()
        nav.pushViewController(detail, animated: false)
        nav.view.layoutIfNeeded()
        XCTAssertEqual(popover.presentationState, .presented)
        XCTAssertTrue(popover.reasons.isEmpty)
        XCTAssertTrue(session.window.isKeyWindow)
        nav.popViewController(animated: false)
        nav.view.layoutIfNeeded()
        XCTAssertEqual(popover.presentationState, .presented)
        nav.pushViewController(detail, animated: false)
        popover.dismissPopover(animated: false)
        XCTAssertTrue(source.isKeyWindow)
        XCTAssertNil(session.window.rootViewController)
        XCTAssertEqual(popover.reasons.count, 1)
    }

    @MainActor
    func testPassthroughHitTestingHasNoDismissalSideEffectsAndObserversAreRemoved() throws {
        let (_, source) = try source()
        defer { source.isHidden = true }
        let initialGestures = source.gestureRecognizers?.count ?? 0
        let popover = RecordingWindowPopover(configuration: .centerDialog)
        popover.configuration.allowsEventPenetration = true
        popover.configuration.autoHideWhenPenetrated = true
        XCTAssertTrue(popover.show(over: source, animated: false))
        let session = try XCTUnwrap(popover.windowSession)
        XCTAssertGreaterThan(source.gestureRecognizers?.count ?? 0, initialGestures)
        for _ in 0..<5 { XCTAssertNil(session.window.hitTest(CGPoint(x: 5, y: 5), with: nil)) }
        XCTAssertEqual(popover.presentationState, .presented)
        XCTAssertTrue(popover.reasons.isEmpty)
        popover.configuration.autoHideWhenPenetrated = false
        XCTAssertEqual(source.gestureRecognizers?.count ?? 0, initialGestures)
        popover.configuration.autoHideWhenPenetrated = true
        popover.shouldDismiss = { _ in false }
        session.requestOutsideDismissal()
        XCTAssertEqual(popover.presentationState, .presented)
        popover.shouldDismiss = nil
        popover.dismissPopover(animated: false)
        session.requestOutsideDismissal()
        XCTAssertEqual(source.gestureRecognizers?.count ?? 0, initialGestures)
        XCTAssertEqual(popover.reasons.count, 1)
    }

    @MainActor
    func testClosureRemovesWindowBeforeCompletionAndCanImmediatelyReshow() throws {
        let (scene, source) = try source()
        defer { source.isHidden = true }
        let popover = BonePopoverView(configuration: .centerDialog)
        weak var oldWindow: UIWindow?
        var calls = 0
        // 排除 UIKit 窗口查询返回值的临时自动释放引用，再检查 SDK 是否仍持有旧窗口。
        autoreleasepool {
            XCTAssertTrue(popover.show(over: source, animated: false))
            oldWindow = popover.view.window
            popover.dismissPopover(animated: false) {
                calls += 1
                XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
                XCTAssertTrue(source.isKeyWindow)
                XCTAssertNil(popover.parent)
                XCTAssertTrue(popover.show(over: source, animated: false))
            }
        }
        XCTAssertEqual(calls, 1)
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in oldWindow == nil }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [released], timeout: 3), .completed)
        XCTAssertNil(oldWindow)
        XCTAssertEqual(popover.presentationState, .presented)
        popover.dismissPopover(animated: false)
    }
    @MainActor
    func testHiddenSourceCleansWindowAndReleasesPopover() throws {
        let (scene, source) = try source()
        weak var releasedPopover: BonePopoverView?
        weak var releasedWindow: UIWindow?
        let removed = expectation(description: "hidden source removes owned window")
        autoreleasepool {
            var popover: RecordingWindowPopover? = RecordingWindowPopover(configuration: .centerDialog)
            XCTAssertTrue(popover!.show(over: source, animated: false))
            releasedPopover = popover
            releasedWindow = popover?.view.window
            popover?.notificationDismissComplete = { removed.fulfill() }
            popover = nil
            XCTAssertNotNil(releasedPopover)
            source.isHidden = true
        }
        wait(for: [removed], timeout: 3)
        XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
        XCTAssertNil(releasedPopover)
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in releasedWindow == nil }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [released], timeout: 3), .completed)
        XCTAssertNil(releasedWindow)
    }
    @MainActor
    func testAutomaticAndNavigationCompatibilityEntrypoints() throws {
        let (_, source) = try source()
        defer { source.isHidden = true }
        let active = UIApplication.shared.connectedScenes.filter { $0.activationState == .foregroundActive }
        let popover = BonePopoverView(configuration: .centerDialog)
        popover.configuration.animation = .none
        XCTAssertEqual(popover.show(), active.count == 1)
        if popover.isPresented {
            XCTAssertNotNil(popover.windowSession)
            popover.dismissPopover(animated: false)
        }
        XCTAssertEqual(popover.show(isNav: true), active.count == 1)
        if popover.isPresented {
            XCTAssertNotNil(popover.navigationController)
            popover.dismissPopover(animated: false)
        }
    }

    @MainActor
    func testClosingDuringEntryCompletesEachRequestOnce() async throws {
        let (scene, source) = try source()
        defer { source.isHidden = true }
        let popover = RecordingWindowPopover(configuration: .centerDialog)
        popover.configuration.animation = .scale
        let first = expectation(description: "first close")
        let second = expectation(description: "second close")
        var shows = 0
        popover.onDidShow = { shows += 1 }
        XCTAssertTrue(popover.show(over: source))
        popover.hidden { first.fulfill() }
        popover.hidden { second.fulfill() }
        await fulfillment(of: [first, second], timeout: 4)
        XCTAssertEqual(shows, 0)
        XCTAssertEqual(popover.reasons.count, 1)
        XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
        XCTAssertTrue(source.isKeyWindow)
    }

    @MainActor
    func testSceneDisconnectClearsAllOwnedWindows() throws {
        let (scene, source) = try source()
        defer { source.isHidden = true }
        let first = RecordingWindowPopover(configuration: .centerDialog)
        let second = RecordingWindowPopover(configuration: .centerDialog)
        XCTAssertTrue(first.show(over: source, animated: false))
        XCTAssertTrue(second.show(in: scene, animated: false))
        let windows = PopoverWindowCoordinator.shared.sessions(in: scene).map(\.window)
        // 注入通知验证清理路径；真实双 Scene 激活、隔离与销毁由 PopoverWindowSceneTests 验证。
        NotificationCenter.default.post(name: UIScene.didDisconnectNotification, object: scene)
        XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
        XCTAssertTrue(windows.allSatisfy { $0.isHidden && $0.rootViewController == nil })
        XCTAssertEqual(first.reasons.first, .hostRemoved)
        XCTAssertEqual(second.reasons.first, .hostRemoved)
    }

    @MainActor
    func testWindowLayoutAvoidsInjectedRegionsAndNotificationKeyboardAcrossHostSizes() throws {
        let (_, source) = try source()
        defer { source.isHidden = true }
        let popover = BonePopoverView(configuration: .centerDialog)
        popover.configuration.layout.width = .fixed(320)
        popover.configuration.layout.height = .fixed(240)
        XCTAssertTrue(popover.show(over: source, animated: false))
        defer { popover.dismissPopover(animated: false) }
        let host = try XCTUnwrap(popover.presentationHost)
        let window = try XCTUnwrap(host.window)
        let originalFrame = host.frame
        // 真实 Window 中注入宿主尺寸；这不等同于操作系统分屏或实体折叠姿态。
        for size in [originalFrame.size, CGSize(width: 300, height: 560), originalFrame.size] {
            host.frame = CGRect(origin: .zero, size: size)
            for vertical in [true, false] {
                let excluded = vertical
                    ? CGRect(x: host.bounds.midX - 12, y: 0, width: 24, height: host.bounds.height)
                    : CGRect(x: 0, y: host.bounds.midY - 12, width: host.bounds.width, height: 24)
                popover.reservedRegionProvider = { _ in [excluded] }
                host.layoutIfNeeded()
                let panel = host.panelFrame
                XCTAssertFalse(panel.isEmpty)
                XCTAssertTrue(panel.intersection(excluded).isNull || panel.intersection(excluded).isEmpty)
                XCTAssertGreaterThanOrEqual(panel.minX, host.bounds.minX)
                XCTAssertLessThanOrEqual(panel.maxX, host.bounds.maxX)
                XCTAssertGreaterThanOrEqual(panel.minY, host.bounds.minY)
                XCTAssertLessThanOrEqual(panel.maxY, host.bounds.maxY)
            }
        }
        host.frame = originalFrame
        popover.reservedRegionProvider = { _ in [] }
        host.layoutIfNeeded()
        let unobstructed = host.panelFrame
        let field = UITextField(frame: CGRect(x: 20, y: 20, width: 180, height: 44))
        popover.baseView.addSubview(field)
        XCTAssertTrue(field.becomeFirstResponder())
        let keyboard = CGRect(x: 0, y: host.bounds.midY, width: host.bounds.width, height: host.bounds.height / 2)
        let screenFrame = window.convert(host.convert(keyboard, to: window), to: window.screen.coordinateSpace)
        let info: [AnyHashable: Any] = [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: screenFrame),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.0,
            UIResponder.keyboardAnimationCurveUserInfoKey: 0
        ]
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: info)
        host.layoutIfNeeded()
        XCTAssertLessThanOrEqual(host.panelFrame.maxY, keyboard.minY)
        XCTAssertFalse(host.panelFrame.isEmpty)
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: info)
        host.layoutIfNeeded()
        XCTAssertEqual(host.panelFrame, unobstructed)
        XCTAssertTrue(popover.view.window === window)
        popover.configuration.appearance = .liquidGlass
        host.layoutIfNeeded()
        XCTAssertTrue(popover.view.window === window)
        XCTAssertEqual(host.panelFrame, unobstructed)
        popover.configuration.appearance = .classic
        host.layoutIfNeeded()
        XCTAssertTrue(popover.view.window === window)
    }
}
