import UIKit
import BonePopoverKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default", sessionRole: session.role)
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        let arguments = ProcessInfo.processInfo.arguments
        // UI 回归显式选择首页，避免上一用例的 Scene 恢复记录改变测试入口。
        let activity = arguments.contains("--demo-home") ? nil
            : options.userActivities.first { $0.activityType == WindowDemoViewController.activityType }
                ?? session.stateRestorationActivity
        let opensWindowDemo = arguments.contains("--window-demo")
            || activity?.activityType == WindowDemoViewController.activityType
        let root: UIViewController = opensWindowDemo
            ? WindowDemoViewController(isAdditionalScene: activity?.userInfo?["secondary"] as? Bool ?? false)
            : DemoViewController(style: .insetGrouped)
        window.rootViewController = UINavigationController(rootViewController: root)
        window.accessibilityIdentifier = "window-business-main"
        self.window = window
        window.makeKeyAndVisible()
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == WindowDemoViewController.activityType else { return }
        if let navigation = window?.rootViewController as? UINavigationController,
           let demo = navigation.viewControllers.compactMap({ $0 as? WindowDemoViewController }).first {
            navigation.popToViewController(demo, animated: false)
        } else {
            let demo = WindowDemoViewController(isAdditionalScene: userActivity.userInfo?["secondary"] as? Bool ?? false)
            window?.rootViewController = UINavigationController(rootViewController: demo)
        }
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        (window?.rootViewController as? UINavigationController)?.viewControllers
            .compactMap { $0 as? WindowDemoViewController }.first?.restorationActivity
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        (window?.rootViewController as? UINavigationController)?.viewControllers
            .compactMap { $0 as? WindowDemoViewController }.forEach { $0.prepareForSceneDisconnect() }
    }
}

final class DemoViewController: UITableViewController {
    private let scenes = ["居中确认框", "输入框与键盘", "底部操作列表", "顶部通知", "侧边面板", "长内容滚动", "注入竖向折叠", "注入横向折叠", "自定义 Alert 尺寸", "Alert 长内容上限", "Alert 竖排按钮", "Alert 窄空间", "自定义字体与间距", "即时调整内容样式", "独立 Window 与多 Scene", "Toast 顶部长条", "Toast 底部长条", "Toast 中间方块"]
    private let styles = ["自动", "经典", "毛玻璃", "液态玻璃", "品牌色"]
    private let motions = ["场景默认", "淡入淡出", "缩放", "弹簧", "自定义"]
    private var selectedStyle = 0
    private var selectedMotion = 0
    private var selectedTitleAlignment: NSTextAlignment = .left
    private var selectedToastType: BoneToastView.ToastType = .success
    private var selectedToastDuration: TimeInterval = 2
    private weak var currentPopover: BonePopoverView?
    private var lastResult = "选择一个场景，体验弹窗。"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BonePopoverKit"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.accessibilityIdentifier = "demo-list"
        updateTitleAlignmentMenu()
        updateToastMenu()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        [scenes.count, styles.count, motions.count][section]
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["常用场景", "外观风格", "动画方式"][section]
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return lastResult
        case 1: return "自动风格在 iOS 26 及以上使用系统玻璃。降低透明度开启时使用纯色背景。"
        default: return "Duo 使用系统保留区域自动避让。注入场景用于演示和测试，不代替真实设备姿态测试。"
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = [scenes, styles, motions][indexPath.section][indexPath.row]
        if indexPath.section == 0 {
            content.image = UIImage(systemName: ["rectangle.center.inset.filled", "keyboard", "list.bullet.rectangle", "rectangle.topthird.inset.filled", "sidebar.right", "scroll", "rectangle.split.2x1", "rectangle.split.1x2", "arrow.left.and.right", "arrow.up.and.down", "rectangle.split.1x2", "arrow.left.and.right", "textformat.size", "slider.horizontal.3", "macwindow.on.rectangle", "rectangle.topthird.inset.filled", "rectangle.bottomthird.inset.filled", "square.inset.filled"][indexPath.row])
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "scene-\(indexPath.row)"
        } else {
            let selected = indexPath.section == 1 ? selectedStyle : selectedMotion
            cell.accessoryType = indexPath.row == selected ? .checkmark : .none
        }
        cell.contentConfiguration = content
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 { selectedStyle = indexPath.row; tableView.reloadData(); return }
        if indexPath.section == 2 { selectedMotion = indexPath.row; tableView.reloadData(); return }
        showScene(indexPath.row)
    }

    private func updateTitleAlignmentMenu() {
        let options: [(String, NSTextAlignment)] = [("左对齐", .left), ("居中", .center), ("右对齐", .right)]
        let actions = options.map { title, alignment in
            UIAction(title: title, state: selectedTitleAlignment == alignment ? .on : .off) { [weak self] _ in
                self?.selectedTitleAlignment = alignment
                self?.updateTitleAlignmentMenu()
            }
        }
        let item = UIBarButtonItem(title: "标题对齐", menu: UIMenu(title: "标题位置", children: actions))
        item.accessibilityIdentifier = "title-alignment"
        let interactions = UIBarButtonItem(title: "关闭交互", style: .plain, target: self, action: #selector(showInteractions))
        interactions.accessibilityIdentifier = "interaction-demo"
        navigationItem.rightBarButtonItems = [item, interactions]
    }

    private func updateToastMenu() {
        let types: [(String, BoneToastView.ToastType)] = [
            ("成功", .success), ("失败", .failure), ("提示", .info), ("加载中", .loading)
        ]
        let typeActions = types.map { title, type in
            UIAction(title: title, state: selectedToastType == type ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.selectedToastType = type
                if let toast = self.currentPopover as? BoneToastView {
                    toast.message = self.toastMessage(style: toast.style)
                    toast.type = type
                }
                self.updateToastMenu()
            }
        }
        let durations: [(String, TimeInterval)] = [
            ("1 秒", 1), ("2 秒（默认）", 2), ("3 秒", 3), ("5 秒", 5), ("持续显示", 0)
        ]
        let durationActions = durations.map { title, duration in
            UIAction(title: title, state: selectedToastDuration == duration ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.selectedToastDuration = duration
                (self.currentPopover as? BoneToastView)?.duration = duration
                self.updateToastMenu()
            }
        }
        let menu = UIMenu(children: [
            UIMenu(title: "类型", options: .displayInline, children: typeActions),
            UIMenu(title: "自动消失时间", children: durationActions)
        ])
        let item = UIBarButtonItem(title: "Toast", menu: menu)
        item.accessibilityIdentifier = "toast-options"
        navigationItem.leftBarButtonItem = item
    }

    private func toastMessage(style: BoneToastView.Style) -> String {
        switch selectedToastType {
        case .success: style == .center ? "保存成功" : "更改已保存，可以继续操作。"
        case .failure: style == .center ? "操作失败" : "操作失败，请稍后重试。"
        case .info: style == .center ? "提示信息" : "有新消息，请及时查看。"
        case .loading: style == .center ? "加载中…" : "正在加载，请稍候…"
        }
    }

    @objc private func showInteractions() {
        navigationController?.pushViewController(InteractionDemoViewController(), animated: true)
    }

    private var appearance: PopoverAppearance {
        switch selectedStyle {
        case 1: return .classic
        case 2: return .frosted
        case 3: return .liquidGlass
        case 4:
            var value = PopoverAppearance.liquidGlass
            value.tintColor = .systemIndigo
            value.borderWidth = 1
            value.borderColor = .systemIndigo
            value.cornerRadius = 32
            return value
        default: return PopoverAppearance()
        }
    }

    private func showScene(_ index: Int) {
        if let toast = currentPopover as? BoneToastView {
            toast.dismissPopover(animated: false)
        }
        if index == 14 {
            navigationController?.pushViewController(WindowDemoViewController(), animated: true)
            return
        }
        let popover: BonePopoverView
        switch index {
        case 0:
            popover = BoneAlertView(title: "保留熟悉的使用方式", message: "同一份内容，可以切换经典、毛玻璃或系统液态玻璃。") { [weak self] in
                self?.record("已确认")
            }
        case 1:
            popover = BoneAlertView(title: "给项目起个名字", placeholder: "输入项目名称") { [weak self] value in
                self?.record("项目名称：\(value)")
            }
        case 2:
            popover = BoneActionSheetView(title: "项目操作", message: "可在弹窗显示期间切换外观。", actions: [
                PopoverAction("切换风格", image: UIImage(systemName: "paintpalette"), dismissesPopover: false) { [weak self] in
                    guard let self else { return }
                    self.selectedStyle = (self.selectedStyle + 1) % self.styles.count
                    self.currentPopover?.configuration.appearance = self.appearance
                },
                PopoverAction("归档项目", image: UIImage(systemName: "archivebox")) { [weak self] in self?.record("已归档") },
                PopoverAction("删除项目", image: UIImage(systemName: "trash"), role: .destructive) { [weak self] in self?.record("演示：已删除") }
            ])
        case 12:
            let alert = BoneAlertView(title: "自定义字体与间距", message: "标题 22 点粗体，正文 15 点；内边距、段落和按钮间距统一设置。") {}
            var style = PopoverContentStyle()
            style.titleFont = .boldSystemFont(ofSize: 22)
            style.messageFont = .systemFont(ofSize: 15)
            style.buttonFont = .systemFont(ofSize: 16, weight: .medium)
            style.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 28, bottom: 28, trailing: 28)
            style.titleToContentSpacing = 10
            style.contentToButtonsSpacing = 24
            style.buttonSpacing = 18
            style.buttonLayout = .vertical
            alert.configuration.contentStyle = style
            popover = alert
        case 13:
            let sheet = BoneActionSheetView(title: "即时调整内容样式", message: "点击下方按钮，切换默认样式与大字号、宽间距。", actions: [
                PopoverAction("切换字体与间距", image: UIImage(systemName: "textformat.size"), dismissesPopover: false) { [weak self] in
                    self?.toggleContentStyle()
                }
            ])
            sheet.loadViewIfNeeded()
            sheet.actionButtons.first?.accessibilityIdentifier = "toggle-content-style"
            popover = sheet
        case 15, 16, 17:
            let style: BoneToastView.Style = switch index {
            case 15: .top
            case 16: .bottom
            default: .center
            }
            // UI 自动化可延长观察窗口；普通演示默认 2 秒，0 持续显示。
            let duration = selectedToastDuration > 0
                ? ProcessInfo.processInfo.environment["BONE_TOAST_DEMO_DURATION"]
                    .flatMap(TimeInterval.init) ?? selectedToastDuration
                : selectedToastDuration
            popover = BoneToastView(message: toastMessage(style: style), type: selectedToastType,
                                    style: style, duration: duration)
        default:
            let title = scenes[index]
            let message = [5, 8, 9].contains(index) ? String(repeating: "内容会根据当前窗口宽度换行，超出可用高度时可以滚动。\n\n", count: 10)
                : "可以改变窗口尺寸、旋转设备或折叠 Duo，观察弹窗随可用空间调整。"
            let alert = BoneAlertView(title: title, message: message) {}
            if index == 3 { alert.configuration = .topBanner }
            if index == 4 { alert.configuration = .sidePanel }
            if index == 5 { alert.configuration = .bottomSheet }
            if index == 8 {
                alert.horizontalMargin = 48
                alert.maximumSize = CGSize(width: 360, height: 460)
            }
            if index == 10 { alert.buttonLayout = .vertical }
            if index == 11 { alert.maximumSize = CGSize(width: 180, height: 600) }
            if index == 6 || index == 7 {
                alert.reservedRegionProvider = { view in
                    index == 6
                        ? [CGRect(x: view.bounds.midX - 12, y: 0, width: 24, height: view.bounds.height)]
                        : [CGRect(x: 0, y: view.bounds.midY - 12, width: view.bounds.width, height: 24)]
                }
            }
            popover = alert
        }
        popover.configuration.appearance = appearance
        if let alert = popover as? BoneAlertView {
            alert.titleAlignment = selectedTitleAlignment
            alert.titleLabel.accessibilityIdentifier = "popover-title"
            alert.messageLabel.accessibilityIdentifier = "popover-message"
            alert.cancelButton.accessibilityIdentifier = "popover-cancel"
            alert.confirmButton.accessibilityIdentifier = "popover-confirm"
        } else if let sheet = popover as? BoneActionSheetView {
            sheet.titleAlignment = selectedTitleAlignment
            sheet.titleLabel.accessibilityIdentifier = "popover-title"
            sheet.messageLabel.accessibilityIdentifier = "popover-message"
            sheet.cancelButton.accessibilityIdentifier = "popover-cancel"
        } else if let toast = popover as? BoneToastView {
            toast.messageLabel.accessibilityIdentifier = "toast-message"
            toast.imageView.accessibilityIdentifier = "toast-image"
            toast.loadingIndicator.accessibilityIdentifier = "toast-loading"
        }
        popover.baseView.accessibilityIdentifier = "popover-content"
        switch selectedMotion {
        case 1: popover.configuration.animation = .fade
        case 2: popover.configuration.animation = .scale
        case 3: popover.configuration.animation = .spring
        case 4:
            popover.configuration.animation = PopoverAnimation(duration: 0.35, dampingRatio: 0.9) { _, _, _ in
                PopoverVisualState(transform: CGAffineTransform(translationX: 0, y: 36).scaledBy(x: 0.96, y: 0.96), opacity: 0)
            }
        default: break
        }
        currentPopover = popover
        popover.onDidShow = { [weak popover] in
            popover?.view.accessibilityIdentifier = "popover-ready"
        }
        // Present in the navigation controller so the overlay covers its bars as well.
        popover.show(from: navigationController ?? self)
    }

    private func toggleContentStyle() {
        guard let popover = currentPopover else { return }
        var style = PopoverContentStyle()
        style.titleAlignment = selectedTitleAlignment
        if popover.configuration.contentStyle.titleFont.pointSize == 18 {
            style.titleFont = .boldSystemFont(ofSize: 24)
            style.messageFont = .systemFont(ofSize: 19)
            style.buttonFont = .systemFont(ofSize: 20, weight: .medium)
            style.contentInsets = NSDirectionalEdgeInsets(top: 32, leading: 32, bottom: 32, trailing: 32)
            style.titleToContentSpacing = 20
            style.contentToButtonsSpacing = 28
            style.buttonSpacing = 20
        }
        popover.configuration.contentStyle = style
    }

    private func record(_ result: String) {
        lastResult = result
        tableView.reloadData()
    }
}
