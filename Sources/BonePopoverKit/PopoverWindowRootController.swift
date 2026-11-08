import UIKit

/// 窗口展示前捕获的业务状态，避免状态栏 getter 间接读取浮层自身形成递归。
@MainActor
struct PopoverWindowAppearanceContext {
    let statusBarHidden: Bool
    let statusBarStyle: UIStatusBarStyle
    let statusBarAnimation: UIStatusBarAnimation
    let orientations: UIInterfaceOrientationMask
    let autorotates: Bool

    init(source: UIViewController) {
        statusBarHidden = source.prefersStatusBarHidden
        statusBarStyle = source.preferredStatusBarStyle
        statusBarAnimation = source.preferredStatusBarUpdateAnimation
        orientations = source.supportedInterfaceOrientations
        autorotates = source.shouldAutorotate
    }
}

/// 透明全尺寸宿主。实际内容仍由 PopoverHostView 布局、绘制和执行动画。
@MainActor
final class PopoverWindowRootController: UIViewController {
    weak var session: PopoverWindowSession?
    let appearance: PopoverWindowAppearanceContext
    private var hasBeenContained = false

    init(appearance: PopoverWindowAppearanceContext) {
        self.appearance = appearance
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(appearance:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    // 子弹窗的出现/消失由现有状态机精确管理；导航宿主的临时离屏不关闭弹窗。
    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
    override var prefersStatusBarHidden: Bool { appearance.statusBarHidden }
    override var preferredStatusBarStyle: UIStatusBarStyle { appearance.statusBarStyle }
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent != nil { hasBeenContained = true }
        else if hasBeenContained {
            // 与临时离屏区分：根宿主真正从导航栈移除后结束窗口，等待导航修改先完成。
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent == nil, let session = self.session,
                      session.state == .visible else { return }
                session.popover?.dismissPopover(animated: false, reason: .hostRemoved)
            }
        }
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { appearance.statusBarAnimation }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { appearance.orientations }
    override var shouldAutorotate: Bool { appearance.autorotates }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        session?.configurationDidChange()
        session?.popover?.invalidatePopoverLayout()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.configurationDidChange()
    }
}

/// 仅封装通用 UIKit 导航行为，不引入 App 的 TabBar、主题或自定义阅读转场。
@MainActor
final class PopoverWindowNavigationController: UINavigationController {
    override var childForStatusBarHidden: UIViewController? { topViewController }
    override var childForStatusBarStyle: UIViewController? { topViewController }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        topViewController?.supportedInterfaceOrientations ?? .all
    }
    override var shouldAutorotate: Bool { topViewController?.shouldAutorotate ?? true }
}
