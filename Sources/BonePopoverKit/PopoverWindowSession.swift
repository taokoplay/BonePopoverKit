import UIKit

/// 一次独立窗口展示的所有权边界。协调器持有会话，其余参与者仅弱引用会话。
@MainActor
final class PopoverWindowSession {
    enum State { case preparing, visible, finished }
    let identifier: UUID
    let configuration: PopoverWindowConfiguration
    let window: PopoverWindow
    let root: PopoverWindowRootController
    let navigation: PopoverWindowNavigationController?
    weak var popover: BonePopoverView?
    weak var sourceWindow: UIWindow?
    weak var previousKeyWindow: UIWindow?
    weak var previousFirstResponder: UIView?
    private(set) var state: State = .preparing
    private var outsideObserver: PopoverOutsideTapObserver?

    init(identifier: UUID, popover: BonePopoverView, source: UIWindow,
         configuration: PopoverWindowConfiguration, level: UIWindow.Level, scene: UIWindowScene) {
        self.identifier = identifier
        self.popover = popover
        self.sourceWindow = source
        self.configuration = configuration
        previousKeyWindow = scene.keyWindow
        previousFirstResponder = scene.keyWindow.flatMap { Self.firstResponder(in: $0) }
        let sourceController = Self.visibleController(source.rootViewController ?? UIViewController())
        root = PopoverWindowRootController(appearance: PopoverWindowAppearanceContext(source: sourceController))
        window = PopoverWindow(windowScene: scene)
        if configuration.container == .navigation {
            navigation = PopoverWindowNavigationController(rootViewController: root)
            navigation?.setNavigationBarHidden(true, animated: false)
        } else {
            navigation = nil
        }
        window.session = self
        window.acceptsKey = configuration.keyPolicy == .takeAndRestore
        root.session = self
        window.backgroundColor = .clear
        window.windowLevel = level
        // 沿用源窗口显式设置的主题；unspecified 继续跟随 Scene 的系统环境。
        window.overrideUserInterfaceStyle = source.overrideUserInterfaceStyle
        window.rootViewController = navigation ?? root
    }

    var isPopoverRootVisible: Bool {
        state != .finished && !window.isHidden && root.viewIfLoaded?.window === window &&
            (navigation == nil || navigation?.topViewController === root) && root.presentedViewController == nil
    }

    /// 导航 push 后宿主暂时离屏，但窗口会话仍然有效，不应当作永久移除。
    var keepsDetachedHost: Bool {
        state != .finished && configuration.container == .navigation && window.rootViewController === navigation &&
            navigation?.viewControllers.contains(where: { $0 === root }) == true && !window.isHidden
    }

    func showWindow() {
        guard state == .preparing else { return }
        state = .visible
        // 先加载根宿主，再刷新窗口布局；被上层遮挡的非 key 窗口也需要同步建立承载关系。
        window.rootViewController?.loadViewIfNeeded()
        if configuration.keyPolicy == .takeAndRestore { window.makeKeyAndVisible() }
        else { window.isHidden = false }
        window.setNeedsLayout()
        window.layoutIfNeeded()
        window.rootViewController?.view.layoutIfNeeded()
        configurationDidChange()
    }

    func configurationDidChange() {
        guard state == .visible else { return }
        let observes = popover.map {
            $0.configuration.allowsEventPenetration && $0.configuration.autoHideWhenPenetrated
        } ?? false
        if observes && isPopoverRootVisible {
            if outsideObserver == nil { outsideObserver = PopoverOutsideTapObserver(session: self) }
            outsideObserver?.updateWindows()
        } else {
            outsideObserver?.invalidate()
            outsideObserver = nil
        }
    }

    func containsPanel(_ point: CGPoint, in source: UIView) -> Bool {
        guard isPopoverRootVisible, let host = popover?.presentationHost else { return false }
        return host.containsPanel(source.convert(point, to: host))
    }

    /// 只允许触发本次展示的请求，避免旧手势或通知关闭回调里重显的新弹窗。
    func requestOutsideDismissal() {
        guard state == .visible, let popover, popover.presentationIdentifier == identifier,
              popover.configuration.allowsEventPenetration,
              popover.configuration.autoHideWhenPenetrated else { return }
        popover.requestDismiss(reason: .penetration)
    }

    /// 先注销所有权和输入观察，再交还 key，最后允许业务回调运行。
    @discardableResult
    func finish(restoringFocus: Bool = true) -> Bool {
        guard state != .finished else { return false }
        state = .finished
        outsideObserver?.invalidate()
        outsideObserver = nil
        return PopoverWindowCoordinator.shared.remove(self, restoringFocus: restoringFocus)
    }

    static func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        return view.subviews.lazy.compactMap { firstResponder(in: $0) }.first
    }

    static func visibleController(_ root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController { return visibleController(presented) }
        if let nav = root as? UINavigationController, let visible = nav.visibleViewController { return visibleController(visible) }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController { return visibleController(selected) }
        return root
    }
}
