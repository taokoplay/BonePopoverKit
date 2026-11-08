import UIKit
import BonePopoverKit

private enum WindowPopoverKind: String {
    case first, fixed, automaticStack = "auto", input, preserve, navigation, scene, automatic
    case automaticNavigation = "automatic-nav"
    case transparent, passthrough, penetrateDismiss = "penetrate-dismiss", veto, sourceClose = "source-close"
}

/// 仅用公开 API 观察业务窗口、输入焦点与弹窗之间的关系。
final class WindowDemoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    static let activityType = "dev.bone.window-demo"
    let isAdditionalScene: Bool

    private weak var owner: WindowDemoViewController?
    private let isSecondaryBusiness: Bool
    private var shared: WindowDemoViewController { owner ?? self }
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let header = UIStackView()
    private let roleLabel = UILabel()
    private let keyLabel = UILabel()
    private let windowCountLabel = UILabel()
    private let counterLabel = UILabel()
    private let popoverCountLabel = UILabel()
    private let inputLabel = UILabel()
    private let eventLabel = UILabel()
    private let counterButton = UIButton(type: .system)
    private let closeBusinessButton = UIButton(type: .system)
    private var businessWindow: UIWindow?
    private var popovers: [WindowPopoverKind: BonePopoverView] = [:]
    private var readyPopovers: Set<WindowPopoverKind> = []
    private var observers: [NSObjectProtocol] = []
    private var mainCount = 0
    private var secondaryCount = 0
    private var closedBusinessCount = 0
    private var dismissedCount = 0
    private var vetoCount = 0
    private var lastInput = "尚未输入"
    private var event = "底部按钮可验证外部点击是否抵达业务窗口。"
    private var sceneCloseError: NSError?

    private let rows: [[(id: String, title: String)]] = [
        [("open-secondary", "打开第二业务 Window（normal + 10）")],
        [("first", "覆盖两个业务 Window / 叠加层级"), ("input", "输入与 key 恢复"),
         ("preserve", "保留当前 key Window"), ("navigation", "独立 Window 导航栈"),
         ("scene", "指定当前 Scene 展示"), ("automatic", "自动选择唯一前台 Scene"),
         ("automatic-nav", "自动选择 Scene 并启用导航")],
        [("transparent", "透明遮罩：外部关闭并拦截"), ("passthrough", "穿透：只增加底层计数"),
         ("penetrate-dismiss", "穿透：计数并关闭"), ("veto", "穿透：否决自动关闭"),
         ("source-close", "穿透：底层按钮关闭源 Window")],
        [("activate-scene", "激活第二个 Scene")]
    ]

    init(isAdditionalScene: Bool = false) {
        self.isAdditionalScene = isAdditionalScene
        isSecondaryBusiness = false
        super.init(nibName: nil, bundle: nil)
    }

    private init(owner: WindowDemoViewController) {
        self.owner = owner
        isAdditionalScene = owner.isAdditionalScene
        isSecondaryBusiness = true
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("请使用 init()") }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    var restorationActivity: NSUserActivity {
        let activity = NSUserActivity(activityType: Self.activityType)
        activity.title = "独立 Window 演示"
        activity.userInfo = ["secondary": isAdditionalScene]
        return activity
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = isSecondaryBusiness ? "第二业务 Window" : "独立 Window"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        view.accessibilityIdentifier = isSecondaryBusiness ? "window-secondary-screen"
            : isAdditionalScene ? "window-additional-scene-screen" : "window-main-screen"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.accessibilityIdentifier = "window-demo-list"
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52

        header.axis = .vertical
        header.spacing = 6
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        let labels = [roleLabel, keyLabel, windowCountLabel, counterLabel, popoverCountLabel, inputLabel, eventLabel]
        let identifiers = ["window-role-state", "window-key-state", "window-count-state", "window-counter-state",
                           "window-popover-state", "window-input-state", "window-event-state"]
        for (label, identifier) in zip(labels, identifiers) {
            label.font = .preferredFont(forTextStyle: .footnote)
            label.numberOfLines = 0
            label.accessibilityIdentifier = identifier
            header.addArrangedSubview(label)
        }
        tableView.tableHeaderView = header

        counterButton.accessibilityIdentifier = "window-counter"
        counterButton.addAction(UIAction { [weak self] _ in self?.incrementCounter() }, for: .touchUpInside)
        closeBusinessButton.accessibilityIdentifier = "window-close-business"
        closeBusinessButton.addAction(UIAction { [weak self] _ in self?.shared.closeBusinessWindow() }, for: .touchUpInside)
        let footer = UIStackView(arrangedSubviews: [counterButton, closeBusinessButton])
        footer.distribution = .fillEqually
        footer.spacing = 12
        footer.isLayoutMarginsRelativeArrangement = true
        footer.layoutMargins = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        for button in [counterButton, closeBusinessButton] { button.configuration = .tinted() }
        for child in [tableView, footer] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 60)
        ])
        if isAdditionalScene {
            let close = UIBarButtonItem(title: "关闭 Scene", style: .plain, target: self, action: #selector(closeScene))
            close.accessibilityIdentifier = "window-close-scene"
            navigationItem.rightBarButtonItem = close
        }
        if owner == nil {
            let names: [Notification.Name] = [UIWindow.didBecomeKeyNotification, UIWindow.didResignKeyNotification,
                                               UIWindow.didBecomeVisibleNotification, UIWindow.didBecomeHiddenNotification]
            observers = names.map { name in
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    // 窗口通知发生在切换过程中，下一轮再读取公开的 Scene.windows。
                    DispatchQueue.main.async { [weak self] in self?.refreshState() }
                }
            }
        }
        refreshState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shared.refreshState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = header.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: 0),
                                                  withHorizontalFittingPriority: .required,
                                                  verticalFittingPriority: .fittingSizeLevel)
        if header.frame.width != tableView.bounds.width || abs(header.frame.height - size.height) > 1 {
            header.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: size.height)
            tableView.tableHeaderView = header
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if owner == nil, isMovingFromParent { prepareForSceneDisconnect() }
    }

    func prepareForSceneDisconnect() {
        // 离开演示或断开 Scene 时主动释放演示持有的引用。
        let active = Array(popovers.values)
        active.forEach { $0.dismissPopover(animated: false) }
        businessWindow?.isHidden = true
        businessWindow?.rootViewController = nil
        businessWindow = nil
    }

    func numberOfSections(in tableView: UITableView) -> Int { rows.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows[section].count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["业务窗口", "独立弹窗与路由", "透明遮罩与外部触摸", "多 Scene"][section]
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "第二业务窗口与主窗口属于同一 Scene，拥有可交互页面；底部关闭按钮会关闭第二业务窗口本身。"
        case 1: return "默认显式 over 当前业务 Window。首层弹窗内可比较固定低层与自动叠加，并乱序关闭首层。"
        case 2: return "底部计数和关闭按钮始终处于弹窗面板之外。源 Window 关闭时，由 SDK 清理关联弹窗。"
        default: return "iPad 等支持多 Scene 的环境会创建新页面；新页面右上角可关闭 Scene。恢复时仍路由到本页。"
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.section][indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = row.title
        cell.textLabel?.numberOfLines = 0
        cell.accessibilityIdentifier = "window-\(row.id)"
        if row.id == "activate-scene" {
            cell.accessibilityValue = UIApplication.shared.supportsMultipleScenes ? "supported" : "unsupported"
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = rows[indexPath.section][indexPath.row].id
        switch id {
        case "open-secondary": shared.openBusinessWindow()
        case "activate-scene": activateScene()
        default:
            guard let kind = WindowPopoverKind(rawValue: id), let source = view.window else { return }
            shared.showPopover(kind, over: source)
        }
    }

    private func incrementCounter() {
        if isSecondaryBusiness { shared.secondaryCount += 1 } else { shared.mainCount += 1 }
        shared.refreshState()
    }

    private func openBusinessWindow() {
        guard businessWindow == nil, let scene = view.window?.windowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 10)
        window.accessibilityIdentifier = "window-business-secondary"
        window.rootViewController = UINavigationController(rootViewController: WindowDemoViewController(owner: self))
        businessWindow = window
        window.makeKeyAndVisible()
        event = "第二业务 Window 已打开。当前页的弹窗显式绑定此业务窗口。"
        refreshState()
    }

    private func closeBusinessWindow() {
        guard let closing = businessWindow else { return }
        closedBusinessCount += 1
        // 此处只关闭业务 Window，不代 SDK 关闭其弹窗，便于验证源窗口自动清理。
        closing.isHidden = true
        closing.rootViewController = nil
        businessWindow = nil
        if view.window?.windowScene?.windows.contains(where: { $0.isKeyWindow && !$0.isHidden }) == false {
            view.window?.makeKey()
        }
        event = "第二业务 Window 已关闭；检查弹窗数和主窗口计数。"
        refreshState()
    }

    private func keyName(in scene: UIWindowScene?) -> String {
        guard let key = scene?.windows.first(where: { $0.isKeyWindow && !$0.isHidden }) else { return "none" }
        if key === businessWindow { return "secondary" }
        if key === view.window { return "main" }
        if popovers.values.contains(where: { $0.viewIfLoaded?.window === key }) { return "popover" }
        return "other"
    }

    private func refreshState() {
        guard owner == nil else { shared.refreshState(); return }
        updateHeader()
        let secondary = (businessWindow?.rootViewController as? UINavigationController)?.viewControllers.first
            as? WindowDemoViewController
        secondary?.updateHeader()
        let key = keyName(in: view.window?.windowScene)
        (popovers[.input] as? BoneAlertView)?.titleLabel.accessibilityValue = "key:\(key)"
        for panel in popovers.values.compactMap({ $0 as? WindowPanelPopover }) {
            panel.stateLabel.text = "活动弹窗：\(popovers.count)；就绪：\(readyPopovers.count)；key：\(key)\n主计数：\(mainCount)；第二计数：\(secondaryCount)；否决：\(vetoCount)"
            panel.stateLabel.accessibilityValue = "active:\(popovers.count);ready:\(readyPopovers.count);main:\(mainCount);secondary:\(secondaryCount);veto:\(vetoCount);key:\(key)"
        }
    }

    private func updateHeader() {
        guard isViewLoaded else { return }
        let state = shared
        roleLabel.text = "\(isAdditionalScene ? "第二 Scene" : "主 Scene") · \(isSecondaryBusiness ? "第二业务 Window" : "主业务 Window")"
        roleLabel.accessibilityValue = isAdditionalScene ? "additional" : "primary"
        keyLabel.text = "当前 key：\(state.keyName(in: view.window?.windowScene))"
        keyLabel.accessibilityValue = state.keyName(in: view.window?.windowScene)
        let visibleWindows = view.window?.windowScene?.windows.filter { !$0.isHidden } ?? []
        // 只验收本 Demo 创建的业务/弹窗窗口；UIKit 的 UITextEffectsWindow 单独展示诊断。
        let count = visibleWindows.filter { $0.accessibilityIdentifier?.hasPrefix("window-") == true }.count
        let windowTypes = visibleWindows.map { String(describing: type(of: $0)) }.joined(separator: ", ")
        windowCountLabel.text = "业务与弹窗窗口：\(count)；Scene 总数：\(visibleWindows.count)（\(windowTypes)）"
        windowCountLabel.accessibilityValue = String(count)
        counterLabel.text = "主计数：\(state.mainCount)；第二计数：\(state.secondaryCount)；业务窗口关闭：\(state.closedBusinessCount)"
        counterLabel.accessibilityValue = "main:\(state.mainCount);secondary:\(state.secondaryCount);closed:\(state.closedBusinessCount)"
        popoverCountLabel.text = "活动弹窗：\(state.popovers.count)；已完成关闭：\(state.dismissedCount)"
        popoverCountLabel.accessibilityValue = "active:\(state.popovers.count);dismissed:\(state.dismissedCount)"
        inputLabel.text = "输入结果：\(state.lastInput)"
        inputLabel.accessibilityValue = state.lastInput
        eventLabel.text = state.event
        eventLabel.accessibilityValue = state.sceneCloseError.map { "scene-close-error:\($0.domain):\($0.code)" } ?? "none"
        let ownCount = isSecondaryBusiness ? state.secondaryCount : state.mainCount
        counterButton.setTitle("底层计数：\(ownCount)", for: .normal)
        counterButton.accessibilityValue = String(ownCount)
        closeBusinessButton.setTitle(isSecondaryBusiness ? "关闭本业务 Window" : "关闭第二业务 Window", for: .normal)
        closeBusinessButton.isEnabled = state.businessWindow != nil
        view.setNeedsLayout()
    }

    private func showPopover(_ kind: WindowPopoverKind, over source: UIWindow) {
        guard popovers[kind] == nil, !source.isHidden, readyPopovers.count == popovers.count else { return }
        let popover: BonePopoverView
        if kind == .input {
            let alert = BoneAlertView(title: "独立 Window 输入", placeholder: "输入后确认") { [weak self] value in
                self?.lastInput = value
                self?.refreshState()
            }
            alert.titleLabel.accessibilityIdentifier = "window-input-title"
            alert.textField.accessibilityIdentifier = "window-input-field"
            alert.keyboardType = .asciiCapable
            alert.textField.autocorrectionType = .no
            alert.textField.autocapitalizationType = .none
            alert.confirmButton.accessibilityIdentifier = "window-input-confirm"
            alert.cancelButton.accessibilityIdentifier = "window-input-cancel"
            popover = alert
        } else {
            let panel = makePanel(kind, source: source)
            popover = panel
        }
        popover.configuration.appearance = .classic
        popover.configuration.allowsDragToDismiss = false
        popover.configuration.dismissOnBackdropTap = kind == .transparent
        popover.configuration.window.level = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue - 1)
        popover.configuration.window.stacking = .aboveManagedPopovers
        popover.configuration.window.keyPolicy = kind == .preserve || kind == .fixed ? .preserveCurrent : .takeAndRestore
        popover.configuration.window.container = kind == .navigation ? .navigation : .plain
        if kind == .fixed || kind == .automaticStack {
            // 同一个请求层级：固定模式留在首层之下，自动模式叠到已有弹窗之上。
            popover.configuration.window.level = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 11)
            popover.configuration.window.stacking = kind == .fixed ? .fixed : .aboveManagedPopovers
        }
        let penetrates = [WindowPopoverKind.passthrough, .penetrateDismiss, .veto, .sourceClose].contains(kind)
        popover.configuration.showsBackdrop = !(penetrates || kind == .transparent)
        popover.configuration.allowsEventPenetration = penetrates
        popover.configuration.autoHideWhenPenetrated = kind == .penetrateDismiss || kind == .veto
        if kind == .veto {
            popover.shouldDismiss = { [weak self] _ in
                self?.vetoCount += 1
                self?.refreshState()
                return false
            }
        }
        popover.onDidShow = { [weak self, weak popover] in
            guard let self, let popover, self.popovers[kind] === popover else { return }
            self.readyPopovers.insert(kind)
            popover.view.accessibilityIdentifier = "window-popup-\(kind.rawValue)-ready"
            popover.view.window?.accessibilityIdentifier = "window-popover-\(kind.rawValue)"
            self.refreshState()
        }
        popover.notificationDismissComplete = { [weak self, weak popover] in
            guard let self, let popover, self.popovers[kind] === popover else { return }
            self.popovers.removeValue(forKey: kind)
            self.readyPopovers.remove(kind)
            self.dismissedCount += 1
            self.refreshState()
        }
        popovers[kind] = popover
        let shown: Bool
        switch kind {
        case .scene:
            shown = source.windowScene.map { popover.show(in: $0) } ?? false
        case .automatic: shown = popover.show()
        case .automaticNavigation: shown = popover.show(isNav: true)
        default: shown = popover.show(over: source)
        }
        if !shown {
            popovers.removeValue(forKey: kind)
            readyPopovers.remove(kind)
            event = "展示失败：请确认源窗口可见；自动路由要求唯一前台 Scene。"
        }
        refreshState()
    }

    private func makePanel(_ kind: WindowPopoverKind, source: UIWindow) -> WindowPanelPopover {
        let messages: [WindowPopoverKind: String] = [
            .first: "独立弹窗覆盖同 Scene 的两个业务窗口。可在面板内比较固定与自动层级。",
            .fixed: "请求 normal + 11，固定层级；应位于首层弹窗下方、两个业务窗口上方。",
            .automaticStack: "请求 normal + 11，自动叠加；应显示在首层上方。可先关闭首层。",
            .preserve: "弹窗保持源业务窗口的 key 身份，关闭后仍可操作源窗口。",
            .navigation: "点击 push，再返回或直接关闭整个独立 Window 导航栈。",
            .automaticNavigation: "自动选择唯一前台 Scene，并创建带导航的独立 Window。",
            .scene: "通过当前业务 Window 的 windowScene 显式展示。",
            .automatic: "仅当只有一个前台 Scene 时，自动路由才会成功。",
            .transparent: "点击底部计数所在位置：关闭弹窗，底层计数保持不变。",
            .passthrough: "点击底部计数：底层增加一次，弹窗继续显示。",
            .penetrateDismiss: "同一次点击会增加底层计数并关闭弹窗。",
            .veto: "点击底部计数仍会穿透，但 shouldDismiss 否决自动关闭。",
            .sourceClose: "先打开第二业务 Window，再点击底部“关闭本业务 Window”，观察弹窗自动清理。"
        ]
        let panel = WindowPanelPopover(kind: kind.rawValue, message: messages[kind] ?? "")
        if kind == .first {
            panel.addButton("叠加固定低层", id: "window-stack-fixed") { [weak self, weak source] in
                guard let source else { return }
                self?.showPopover(.fixed, over: source)
            }
            panel.addButton("叠加自动低层", id: "window-stack-auto") { [weak self, weak source] in
                guard let source else { return }
                self?.showPopover(.automaticStack, over: source)
            }
            panel.addButton("即时更新内容与样式", id: "window-update-live") { [weak panel] in
                guard let panel else { return }
                panel.titleLabel.text = "内容与布局已即时更新"
                panel.configuration.contentStyle.titleFont = .boldSystemFont(ofSize: 21)
                panel.configuration.appearance.backgroundColor = .systemYellow
                panel.configuration.layout.maximumWidth = 320
                // Window 配置只影响下次创建；本次的容器、key 和层级保留展示时快照。
                panel.configuration.window.level = .normal
                panel.configuration.window.stacking = .fixed
                panel.configuration.window.keyPolicy = .preserveCurrent
                panel.configuration.window.container = .navigation
            }
        }
        if kind == .automaticStack {
            panel.addButton("先关闭首层", id: "window-close-first") { [weak self] in
                self?.popovers[.first]?.dismissPopover()
            }
        }
        if kind == .navigation || kind == .automaticNavigation {
            panel.addButton("Push 详情", id: "window-navigation-push") { [weak panel] in
                guard let panel else { return }
                panel.navigationController?.pushViewController(WindowNavigationDetailViewController(popover: panel), animated: true)
            }
        }
        panel.addButton("关闭当前弹窗", id: "window-popup-\(kind.rawValue)-close") { [weak panel] in
            // 手动退出演示时撤销 veto，保留外部点击时的否决行为。
            if kind == .veto { panel?.shouldDismiss = nil }
            panel?.hidden()
        }
        return panel
    }

    private func activateScene() {
        guard UIApplication.shared.supportsMultipleScenes else {
            shared.event = "当前设备不支持多 Scene；请使用 iPad。"
            shared.refreshState()
            return
        }
        let activity = NSUserActivity(activityType: Self.activityType)
        activity.title = "第二 Scene 的独立 Window 演示"
        activity.userInfo = ["secondary": true]
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil) { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                self?.shared.event = "Scene 激活失败：\(error.localizedDescription)"
                self?.shared.refreshState()
            }
        }
    }

    @objc private func closeScene() {
        guard let scene = view.window?.windowScene else { return }
        UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil) { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                self?.shared.event = "Scene 关闭失败：\(error.localizedDescription)"
                self?.shared.sceneCloseError = error as NSError
                self?.shared.refreshState()
            }
        }
    }
}

/// 自定义面板将按钮放进 baseView；布局与展示均交给公开扩展点。
private final class WindowPanelPopover: BonePopoverView {
    let titleLabel = UILabel()
    let stateLabel = UILabel()
    private let messageLabel = UILabel()
    private let stack = UIStackView()

    init(kind: String, message: String) {
        super.init(nibName: nil, bundle: nil)
        configuration = .centerDialog
        title = "独立 Window 导航"
        titleLabel.text = "独立 Window · \(kind)"
        titleLabel.accessibilityIdentifier = "window-popup-\(kind)-title"
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        stateLabel.font = .preferredFont(forTextStyle: .caption1)
        stateLabel.accessibilityIdentifier = "window-popup-\(kind)-state"
        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        for label in [titleLabel, messageLabel, stateLabel] {
            label.numberOfLines = 0
            stack.addArrangedSubview(label)
        }
        setContentView(stack)
        baseView.accessibilityIdentifier = "window-popup-\(kind)-content"
        applyContentStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("请使用 init(kind:message:)") }

    override func applyContentStyle() {
        titleLabel.font = configuration.contentStyle.titleFont
        messageLabel.font = configuration.contentStyle.messageFont
    }

    func addButton(_ title: String, id: String, action: @escaping () -> Void) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = id
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        stack.addArrangedSubview(button)
    }
}

private final class WindowNavigationDetailViewController: UITableViewController {
    private weak var popover: BonePopoverView?

    init(popover: BonePopoverView) {
        self.popover = popover
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("请使用 init(popover:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Window 导航详情"
        tableView.accessibilityIdentifier = "window-navigation-detail"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 2 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = indexPath.row == 0 ? "Pop 返回弹窗" : "关闭整个 Window 导航栈"
        cell.accessibilityIdentifier = indexPath.row == 0 ? "window-navigation-pop" : "window-navigation-close-stack"
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 { navigationController?.popViewController(animated: true) }
        else { popover?.dismissPopover() }
    }
}
