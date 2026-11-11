import UIKit

public enum PopoverDismissReason: Sendable {
    case normal, penetration, slide, accessibility, hostRemoved
}

/// Compatibility for existing notificationHidden(type:) overrides.
public typealias CLPopoverDismissType = PopoverDismissReason

/// An extensible view controller, matching the original BonePopoverView's inheritance model.
/// Add content to baseView. Override preferredPopoverSize(fitting:) for manual layouts.
@MainActor
open class BonePopoverView: UIViewController {
    public enum PopupType { case alert, sheet, fadeIn }
    public enum PresentationState { case hidden, presenting, presented, dismissing }

    /// 弹窗的统一配置，修改子字段会刷新已加载的内容或当前展示的宿主。
    /// 整份赋值会同时替换外观、内容样式、布局及动画等配置。
    public var configuration = PopoverConfiguration.centerDialog {
        didSet {
            if let hostView { hostView.configurationDidChange() }
            else if isViewLoaded { applyContentStyle() }
        }
    }
    public let baseView = UIView()
    public var customBackgroundView: UIView? {
        didSet { hostView?.configurationDidChange() }
    }
    /// Override system exclusions, e.g. for a custom display or deterministic preview.
    /// Return rectangles in the supplied host view's coordinates; margins are already included.
    public var reservedRegionProvider: ((UIView) -> [CGRect])? {
        didSet { invalidatePopoverLayout() }
    }
    public var shouldDismiss: ((PopoverDismissReason) -> Bool)?
    public var onDidShow: (() -> Void)?
    public var notificationDismissComplete: (() -> Void)?
    public private(set) var presentationState: PresentationState = .hidden
    public private(set) var isShowKeyboard = false
    /// Keyboard end frame in screen coordinates, retained for migration.
    public private(set) var keyboardFrameEnd = CGRect.zero
    public var key: String { identifier.uuidString }
    public var isPresented: Bool { presentationState != .hidden }

    public var popupType: PopupType = .alert {
        didSet {
            switch popupType {
            case .alert:
                configuration.layout.placement = .center
                configuration.animation = .scale
            case .sheet:
                configuration.layout.placement = .bottom
                configuration.animation = .slide(.bottom)
            case .fadeIn: configuration.animation = .fade
            }
        }
    }

    private let identifier = UUID()
    private var hostView: PopoverHostView?
    private(set) var presentationIdentifier: UUID?
    weak var windowSession: PopoverWindowSession?
    var presentationHost: PopoverHostView? { hostView }
    private var dismissCompletions: [() -> Void] = []
    private var finishingIdentifier: UUID?
    private var addingChildIdentifier: UUID?
    private var deferredDismissal: (animated: Bool, reason: PopoverDismissReason)?
    private var appearanceTransitionInFlight = false
    private var managedContent: UIView?
    private weak var previousAccessibilityFocus: AnyObject?

    public override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
    }

    public convenience init(configuration: PopoverConfiguration) {
        self.init(nibName: nil, bundle: nil)
        self.configuration = configuration
    }

    public convenience init(contentView: UIView, configuration: PopoverConfiguration? = nil) {
        self.init(configuration: configuration ?? .bottomSheet)
        setContentView(contentView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("Use init(configuration:)") }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        baseView.backgroundColor = .clear
        view.addSubview(baseView)
        baseView.frame = view.bounds
        baseView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        baseView.frame = view.bounds
    }

    /// 将 configuration.contentStyle 应用到自定义业务控件的扩展钩子。
    /// SDK 会在配置或系统字号变化时调用；子类也应在构建完控件后主动调用一次。
    open func applyContentStyle() {}

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if isViewLoaded,
           previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            // 子控件会在本轮布局的后续阶段接收继承的环境变化。
            // 等传播完成后再刷新字体并重新测量，避免面板高度沿用旧字号的尺寸。
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isViewLoaded else { return }
                self.applyContentStyle()
                self.invalidatePopoverLayout()
            }
        }
    }

    public func setContentView(_ content: UIView) {
        loadViewIfNeeded()
        managedContent?.removeFromSuperview()
        managedContent = content
        baseView.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
            content.topAnchor.constraint(equalTo: baseView.topAnchor),
            content.bottomAnchor.constraint(equalTo: baseView.bottomAnchor)
        ])
        invalidatePopoverLayout()
    }

    /// Called again when the host resizes, keyboard changes, or a reserved region changes.
    open func preferredPopoverSize(fitting availableSize: CGSize) -> CGSize {
        if preferredContentSize.height > 0 { return preferredContentSize }
        let measured = baseView.systemLayoutSizeFitting(
            CGSize(width: availableSize.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        return CGSize(width: availableSize.width, height: measured.height > 0 ? measured.height : 300)
    }

    public func invalidatePopoverLayout() {
        hostView?.setNeedsUpdateConstraints()
        hostView?.setNeedsLayout()
    }

    /// 页面内展示，覆盖范围为传入控制器的 view；不会创建独立 Window。
    @discardableResult
    public func show(from presenter: UIViewController, animated: Bool = true) -> Bool {
        guard presenter !== self, presenter.viewIfLoaded?.window != nil,
              let token = reservePresentation() else { return false }
        return mount(in: presenter, identifier: token, animated: animated)
    }

    /// 在指定源窗口所属的 Scene 中创建独立弹窗 Window。
    /// 源窗口必须可见且有有效根控制器，配置不合法时返回 false，不改变 key Window。
    @discardableResult
    public func show(over sourceWindow: UIWindow, animated: Bool = true) -> Bool {
        showWindow(over: sourceWindow, options: configuration.window, animated: animated)
    }

    /// 在明确指定的 Scene 中独立窗口展示；该 Scene 无有效业务宿主时返回 false。
    @discardableResult
    public func show(in scene: UIWindowScene, animated: Bool = true) -> Bool {
        guard let source = PopoverWindowCoordinator.shared.sourceWindow(in: scene) else { return false }
        return show(over: source, animated: animated)
    }

    /// 兼容旧版无参调用，以独立 Window 展示；多个前台 Scene 时拒绝自动猜测。
    @discardableResult
    open func show() -> Bool {
        guard let scene = Self.unambiguousScene() else { return false }
        return show(in: scene)
    }

    /// 兼容旧版导航入口；true 为本次独立窗口创建 UIKit 导航容器。
    @discardableResult
    open func show(isNav: Bool) -> Bool {
        guard let scene = Self.unambiguousScene(),
              let source = PopoverWindowCoordinator.shared.sourceWindow(in: scene) else { return false }
        var options = configuration.window
        options.container = isNav ? .navigation : .plain
        return showWindow(over: source, options: options, animated: true)
    }

    private static func unambiguousScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        return scenes.count == 1 ? scenes.first : nil
    }

    private func reservePresentation() -> UUID? {
        guard presentationState == .hidden, parent == nil, presentingViewController == nil else { return nil }
        let token = UUID()
        presentationIdentifier = token
        presentationState = .presenting
        previousAccessibilityFocus = UIAccessibility.focusedElement(using: .notificationVoiceOver) as AnyObject?
        return token
    }

    private func showWindow(over source: UIWindow, options: PopoverWindowConfiguration, animated: Bool) -> Bool {
        let coordinator = PopoverWindowCoordinator.shared
        guard let scene = source.windowScene, scene.activationState != .unattached,
              let businessSource = coordinator.businessSource(for: source),
              let level = coordinator.resolvedLevel(options, over: source, in: scene),
              let token = reservePresentation() else { return false }
        let session = PopoverWindowSession(identifier: token, popover: self, source: businessSource,
                                          configuration: options, level: level, scene: scene)
        guard presentationIdentifier == token, presentationState == .presenting else {
            session.finish()
            return false
        }
        coordinator.insert(session, in: scene)
        windowSession = session
        session.showWindow()
        guard presentationIdentifier == token, presentationState == .presenting,
              coordinator.isValid(businessSource, in: scene), session.root.viewIfLoaded?.window != nil else {
            if presentationIdentifier == token { dismissPopover(animated: false, reason: .hostRemoved) }
            session.finish()
            return false
        }
        return mount(in: session.root, identifier: token, animated: animated)
    }

    /// 两种展示方式共用挂载、动画和生命周期，先占用状态再触发可重入的 UIKit 回调。
    private func mount(in presenter: UIViewController, identifier token: UUID, animated: Bool) -> Bool {
        guard presentationIdentifier == token, presentationState == .presenting else { return false }
        loadViewIfNeeded()
        guard presentationIdentifier == token, presentationState == .presenting else { return false }
        let host = PopoverHostView(popover: self)
        guard presentationIdentifier == token, presentationState == .presenting else { return false }
        hostView = host
        addingChildIdentifier = token
        presenter.addChild(self)
        addingChildIdentifier = nil
        if let pending = deferredDismissal, presentationIdentifier == token {
            deferredDismissal = nil
            presentationState = .presenting
            dismissPopover(animated: pending.animated, reason: pending.reason)
            return false
        }
        guard presentationIdentifier == token, presentationState == .presenting else { return false }
        beginAppearance(true, animated: animated, identifier: token)
        guard hostView === host, presentationIdentifier == token, presentationState == .presenting else { return false }
        host.frame = presenter.view.bounds
        host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        presenter.view.addSubview(host)
        didMove(toParent: presenter)
        guard hostView === host, presentationIdentifier == token, presentationState == .presenting else { return false }
        host.setNeedsUpdateConstraints()
        host.setNeedsLayout()
        host.layoutIfNeeded()
        windowSession?.configurationDidChange()
        host.transition(visible: true, animated: animated) { [weak self, weak host] in
            guard let self, let host, self.hostView === host, self.presentationIdentifier == token,
                  self.presentationState == .presenting else { return }
            self.presentationState = .presented
            self.finishAppearance()
            guard self.hostView === host, self.presentationIdentifier == token,
                  self.presentationState == .presented else { return }
            if !self.configuration.allowsEventPenetration {
                UIAccessibility.post(notification: .screenChanged, argument: self.baseView)
            }
            self.onDidShow?()
        }
        return true
    }

    open func hidden(_ callback: (() -> Void)? = nil) {
        dismissPopover(completion: callback)
    }

    /// 关闭完成回调在窗口释放及 key/焦点恢复之后执行，可安全继续展示新弹窗。
    public func dismissPopover(animated: Bool = true, reason: PopoverDismissReason = .normal,
                               completion: (() -> Void)? = nil) {
        guard presentationState != .hidden, let token = presentationIdentifier else { completion?(); return }
        if let completion { dismissCompletions.append(completion) }
        guard finishingIdentifier != token else { return }
        // addChild 会先回调 willMove，再建立父子关系；取消延后到关系建立完成后清理。
        if addingChildIdentifier == token {
            presentationState = .dismissing
            if deferredDismissal == nil || reason == .hostRemoved { deferredDismissal = (animated, reason) }
            return
        }
        if presentationState == .dismissing {
            if reason == .hostRemoved {
                hostView?.transition(visible: false, animated: false) { [weak self] in
                    self?.completeDismissal(identifier: token, reason: reason)
                }
            }
            return
        }
        presentationState = .dismissing
        if parent != nil { willMove(toParent: nil) }
        guard presentationIdentifier == token, finishingIdentifier != token else { return }
        if hostView != nil, parent != nil { beginAppearance(false, animated: animated, identifier: token) }
        guard presentationIdentifier == token, finishingIdentifier != token else { return }
        viewIfLoaded?.endEditing(true)
        guard presentationIdentifier == token, finishingIdentifier != token else { return }
        windowSession?.window.endEditing(true)
        guard presentationIdentifier == token, finishingIdentifier != token else { return }
        if let hostView {
            hostView.transition(visible: false, animated: animated) { [weak self] in
                self?.completeDismissal(identifier: token, reason: reason)
            }
        } else {
            completeDismissal(identifier: token, reason: reason)
        }
    }

    private func completeDismissal(identifier token: UUID, reason: PopoverDismissReason) {
        guard presentationIdentifier == token, presentationState == .dismissing, finishingIdentifier != token else { return }
        // 在 endAppearanceTransition 等可重入 UIKit 回调之前占用完成流程。
        finishingIdentifier = token
        finishAppearance()
        viewIfLoaded?.removeFromSuperview()
        hostView?.invalidateObservation()
        hostView?.removeFromSuperview()
        removeFromParent()
        hostView = nil
        let session = windowSession
        let focus = previousAccessibilityFocus
        previousAccessibilityFocus = nil
        windowSession = nil
        let canRestoreFocus = session?.finish(restoringFocus: reason != .hostRemoved) ?? true
        presentationIdentifier = nil
        finishingIdentifier = nil
        presentationState = .hidden
        isShowKeyboard = false
        keyboardFrameEnd = .zero
        let completions = dismissCompletions
        dismissCompletions.removeAll()
        if canRestoreFocus, !configuration.allowsEventPenetration {
            let target = focus as? UIView
            UIAccessibility.post(notification: .screenChanged, argument: target?.window?.isKeyWindow == true ? focus : nil)
        }
        notificationHidden(type: reason)
        notificationDismissComplete?()
        completions.forEach { $0() }
    }

    open func notificationHidden(type: CLPopoverDismissType) {}

    /// Additional application-specific veto after the SDK's scroll/direction checks.
    open func shouldBeginSwipeToDismiss(_ gestureRecognizer: UIPanGestureRecognizer) -> Bool { true }

    open func shouldRecognizeSwipeToDismissSimultaneously(with otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    open override func accessibilityPerformEscape() -> Bool {
        requestDismiss(reason: .accessibility)
    }

    @discardableResult
    func requestDismiss(reason: PopoverDismissReason) -> Bool {
        guard let token = presentationIdentifier, shouldDismiss?(reason) ?? true,
              presentationIdentifier == token,
              presentationState == .presenting || presentationState == .presented else { return false }
        dismissPopover(reason: reason)
        return true
    }

    func updateKeyboard(frame: CGRect, visible: Bool) {
        keyboardFrameEnd = frame
        isShowKeyboard = visible
    }

    private func beginAppearance(_ appearing: Bool, animated: Bool, identifier token: UUID) {
        finishAppearance()
        guard presentationIdentifier == token, finishingIdentifier != token,
              presentationState == (appearing ? .presenting : .dismissing) else { return }
        appearanceTransitionInFlight = true
        beginAppearanceTransition(appearing, animated: animated)
    }

    private func finishAppearance() {
        guard appearanceTransitionInFlight else { return }
        appearanceTransitionInFlight = false
        endAppearanceTransition()
    }

}
