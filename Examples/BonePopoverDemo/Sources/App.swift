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
            : DemoViewController()
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

final class DemoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let scenes = ["居中确认框", "输入框与键盘", "底部操作列表", "顶部通知", "侧边面板", "长内容滚动", "注入竖向折叠", "注入横向折叠", "自定义 Alert 尺寸", "Alert 长内容上限", "Alert 竖排按钮", "Alert 窄空间", "自定义字体与间距", "即时调整内容样式", "独立 Window 与多 Scene", "Toast 顶部长条", "Toast 底部长条", "Toast 中间方块", "操作列表：分组单选与多选", "玻璃遮罩", "操作列表：单组单选", "操作列表：增加拖动分区", "操作列表：固定高度滚动"]
    /// 每个场景一句话说明，直接告诉使用者这里该看什么。
    private let sceneDetails = [
        "标题、正文、确认/取消，可调对齐与按钮排列",
        "自动聚焦、键盘避让，回调带输入文本",
        "UITableView 分组动作，图标、危险操作与点击回调",
        "顶部滑入，遮罩 0.12，不自动消失",
        "贴 trailing，高度填满可用区",
        "内容超出可用高度时内部滚动",
        "竖向保留区避让，不跨铰链",
        "横向保留区避让，两侧各自可点",
        "horizontalMargin / maximumSize 自定义",
        "maximumHeight 600 时内部滚动",
        "buttonLayout = .vertical，确认在上",
        "窄空间（180 点）自动转竖排",
        "contentStyle 全套字体与间距",
        "显示期间切换字号、间距与对齐",
        "show(over:) / show(in:) 多窗口与 Scene",
        "顶部长条，2 秒自动关，允许穿透",
        "底部长条，可点底层页面",
        "中间方块，160–280 点随内容增大",
        "同一操作列表的单选、多选与统一提交",
        "玻璃模糊遮罩：透明度与虚化各自可调",
        "只有一个单选分区，右上“确定”提交",
        "单选 + 拖动排序两个分区，拖完再提交",
        "面板高度固定，行数超出时列表内部滚动"
    ]
    private let sceneIcons = [
        "rectangle.center.inset.filled", "keyboard", "list.bullet.rectangle",
        "rectangle.topthird.inset.filled", "sidebar.right", "scroll",
        "rectangle.split.2x1", "rectangle.split.1x2", "arrow.left.and.right",
        "arrow.up.and.down", "rectangle.grid.1x2", "arrow.down.right.and.arrow.up.left",
        "textformat.size", "slider.horizontal.3", "macwindow.on.rectangle",
        "rectangle.topthird.inset.filled", "rectangle.bottomthird.inset.filled", "square.inset.filled",
        "list.bullet.below.rectangle", "aqi.medium",
        "checkmark.circle", "line.3.horizontal", "arrow.up.and.down.text.horizontal"
    ]
    /// 场景分组；scene-N 编号保持不变，只调整展示顺序。
    private let groups: [(title: String, indices: [Int])] = [
        ("常用弹窗", [0, 1, 2, 3, 4]),
        ("布局与保留区域", [5, 6, 7, 8, 9, 10, 11]),
        ("内容样式", [12, 13, 19]),
        ("底部操作列表", [18, 20, 21, 22]),
        ("独立窗口", [14]),
        ("Toast", [15, 16, 17])
    ]
    private let styles = ["自动", "经典", "毛玻璃", "液态玻璃", "品牌色"]
    private let motions = ["场景默认", "淡入淡出", "缩放", "弹簧", "自定义"]
    private var selectedStyle = 0
    private var selectedMotion = 0
    /// nil 表示沿用预设默认对齐（`.bottomSheet` 为居中）；用户选过菜单后才覆盖。
    private var selectedTitleAlignment: NSTextAlignment?
    private var selectedToastType: BoneToastView.ToastType = .success
    private var selectedToastDuration: TimeInterval = 2
    private weak var currentPopover: BonePopoverView?
    private var lastResult = "选择一个场景，体验弹窗。"

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let styleControl = UISegmentedControl(items: ["自动", "经典", "毛玻璃", "液态玻璃", "品牌色"])
    private let motionControl = UISegmentedControl(items: ["默认", "淡入", "缩放", "弹簧", "自定义"])
    private let backdropControl = UISegmentedControl(items: ["预设", "显示遮罩", "隐藏遮罩", "玻璃遮罩"])
    private let penetrationControl = UISegmentedControl(items: ["预设", "允许穿透", "拦截触摸"])
    /// `--demo-scene` 指定的场景号，等首页真正显示后再弹。
    private var pendingLaunchScene: Int?
    private let resultLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BonePopoverKit"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground
        let header = makeControlHeader()
        let resultBar = makeResultBar()
        configureTableView(below: header, above: resultBar)
        updateTitleAlignmentMenu()
        updateToastMenu()
        prepareLaunchScene()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 场景必须等视图进入窗口后再弹，否则宿主找不到可用的容器。
        guard let scene = pendingLaunchScene else { return }
        pendingLaunchScene = nil
        showScene(scene)
    }

    /// 常驻控制条：外观与动画不再混在场景列表里，改设置不用来回滚动。
    private func makeControlHeader() -> UIView {
        styleControl.selectedSegmentIndex = selectedStyle
        styleControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.selectedStyle = self.styleControl.selectedSegmentIndex
        }, for: .valueChanged)
        styleControl.accessibilityIdentifier = "style-control"

        motionControl.selectedSegmentIndex = selectedMotion
        motionControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.selectedMotion = self.motionControl.selectedSegmentIndex
        }, for: .valueChanged)
        motionControl.accessibilityIdentifier = "motion-control"

        backdropControl.selectedSegmentIndex = 0
        backdropControl.accessibilityIdentifier = "backdrop-control"
        penetrationControl.selectedSegmentIndex = 0
        penetrationControl.accessibilityIdentifier = "penetration-control"

        let stack = UIStackView(arrangedSubviews: [
            controlRow(title: "外观", control: styleControl),
            controlRow(title: "动画", control: motionControl),
            controlRow(title: "遮罩", control: backdropControl),
            controlRow(title: "交互", control: penetrationControl)
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        view.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        return container
    }

    private func controlRow(title: String, control: UISegmentedControl) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, control])
        row.spacing = 8
        row.alignment = .center
        return row
    }

    /// 底部常驻结果条：回调结果不用滚到列表底部才能看到。
    private func makeResultBar() -> UIView {
        let bar = UIView()
        bar.backgroundColor = .secondarySystemBackground
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.font = .preferredFont(forTextStyle: .footnote)
        resultLabel.textColor = .label
        resultLabel.numberOfLines = 2
        resultLabel.text = lastResult
        resultLabel.accessibilityIdentifier = "demo-result"
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(separator)
        bar.addSubview(resultLabel)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: bar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            resultLabel.topAnchor.constraint(equalTo: bar.topAnchor, constant: 10),
            resultLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            resultLabel.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            resultLabel.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -10)
        ])
        view.addSubview(bar)
        bar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        return bar
    }

    private func configureTableView(below header: UIView, above resultBar: UIView) {
        tableView.accessibilityIdentifier = "demo-list"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "scene")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(tableView, belowSubview: resultBar)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: resultBar.topAnchor)
        ])
    }


    func numberOfSections(in tableView: UITableView) -> Int { groups.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups[section].indices.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        groups[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let index = groups[indexPath.section].indices[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "scene", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = scenes[index]
        content.secondaryText = sceneDetails[index]
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: sceneIcons[index])
        content.imageProperties.tintColor = .tintColor
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "scene-\(index)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showScene(groups[indexPath.section].indices[indexPath.row])
    }


    private func updateTitleAlignmentMenu() {
        let options: [(String, NSTextAlignment?)] = [("预设默认", nil), ("左对齐", .left), ("居中", .center), ("右对齐", .right)]
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

    /// 截图与排查用：`--demo-scene 18` 启动后在首页出现时直接打开指定场景。
    private func prepareLaunchScene() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--demo-scene"),
              arguments.indices.contains(flag + 1),
              let index = Int(arguments[flag + 1]) else { return }
        pendingLaunchScene = index
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
            let sheet = BoneDrawerSheetView(title: "项目操作", message: "可在弹窗显示期间切换外观。")
            sheet.addButton(text: "切换风格", icon: UIImage(systemName: "paintpalette"),
                            dismissesPopover: false, accessibilityIdentifier: "operation-style") { [weak self] in
                guard let self, let current = self.currentPopover else { return }
                self.selectedStyle = (self.selectedStyle + 1) % self.styles.count
                self.applyAppearance(to: current)
            }
            sheet.addButton(text: "归档项目", icon: UIImage(systemName: "archivebox"),
                            accessibilityIdentifier: "operation-archive") { [weak self] in
                self?.record("已归档")
            }
            sheet.addButton(text: "删除项目", icon: UIImage(systemName: "trash"), style: .destructive,
                            accessibilityIdentifier: "operation-delete") { [weak self] in
                self?.record("演示：已删除")
            }
            popover = sheet
        case 18:
            let drawer = BoneDrawerSheetView(title: "阅读设置")
            let symbols = ["平移": "rectangle.expand.vertical", "仿真": "book",
                           "上下": "arrow.up.and.down", "浅色": "sun.max",
                           "深色": "moon", "护眼": "eye"]
            for (text, value, section) in [
                ("平移", "0", BoneDrawerSheetView.SectionType.singleSelect("翻页", true)),
                ("仿真", "1", .singleSelect("翻页", false)),
                ("上下", "2", .singleSelect("翻页", false)),
                ("浅色", "light", .multipleSelect("主题", false)),
                ("深色", "dark", .multipleSelect("主题", false)),
                ("护眼", "eye", .multipleSelect("主题", false))
            ] {
                drawer.addButton(text: text, value: value,
                                 icon: symbols[text].flatMap { UIImage(systemName: $0) },
                                 inSection: section)
            }
            drawer.addButton(text: "恢复默认", style: .highlight, inSection: .normal("")) { [weak self] in
                self?.record("抽屉：恢复默认")
            }
            drawer.sheetConfig.openSectionTitle = true
            // 行图标用浅色底板 + 主题色，和系统设置的分组列表一致。
            drawer.sheetConfig.cellIconBackgroundColor = UIColor.systemIndigo.withAlphaComponent(0.12)
            drawer.sheetConfig.cellIconTint = .systemIndigo
            drawer.showsConfirmButton = true   // 多选统一靠右侧“确定”提交
            drawer.selectAction { [weak self] selections in
                let titles = selections.map(\.text).joined(separator: "、")
                self?.record(titles.isEmpty ? "抽屉提交：无选中" : "抽屉提交：\(titles)")
            }
            popover = drawer
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
            let sheet = BoneDrawerSheetView(title: "即时调整内容样式",
                                            message: "点击下方操作，切换标题、说明、行字体与列表间距。")
            sheet.addButton(text: "切换字体与间距", icon: UIImage(systemName: "textformat.size"),
                            dismissesPopover: false, accessibilityIdentifier: "toggle-content-style") { [weak self] in
                self?.toggleContentStyle()
            }
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
        case 20:
            // 变体 1：只有一个单选分区。
            let single = BoneDrawerSheetView(title: "翻页方式")
            for (text, value, selected) in [("平移", "0", true), ("仿真", "1", false), ("上下", "2", false)] {
                single.addButton(text: text, value: value,
                                 icon: UIImage(systemName: "book"),
                                 inSection: .singleSelect("翻页", selected))
            }
            single.sheetConfig.openSectionTitle = true
            single.sheetConfig.cellIconBackgroundColor = UIColor.systemIndigo.withAlphaComponent(0.12)
            single.sheetConfig.cellIconTint = .systemIndigo
            single.showsConfirmButton = true
            single.selectAction { [weak self] selections in
                self?.record("单选提交：\(selections.map(\.text).joined(separator: "、"))")
            }
            popover = single
        case 21:
            // 变体 2：单选 + 拖动排序。
            let drag = BoneDrawerSheetView(title: "翻页与排序")
            drag.addButton(text: "平移", value: "0", icon: UIImage(systemName: "book"),
                           inSection: .singleSelect("翻页", true))
            drag.addButton(text: "仿真", value: "1", icon: UIImage(systemName: "book"),
                           inSection: .singleSelect("翻页", false))
            for (index, text) in ["第一章", "第二章", "第三章"].enumerated() {
                drag.addButton(text: text, value: "\(index)", icon: UIImage(systemName: "line.3.horizontal"),
                               inSection: .drag("拖动排序"))
            }
            drag.sheetConfig.openSectionTitle = true
            drag.sheetConfig.cellIconBackgroundColor = UIColor.systemTeal.withAlphaComponent(0.12)
            drag.sheetConfig.cellIconTint = .systemTeal
            drag.showsConfirmButton = true
            drag.selectAction { [weak self] selections in
                self?.record("提交：\(selections.map(\.text).joined(separator: "、"))")
            }
            popover = drag
        case 22:
            // 变体 3：固定面板高度，行数超出时列表内部滚动。
            let scrolling = BoneDrawerSheetView(title: "长列表")
            for index in 1...14 {
                scrolling.addButton(text: "选项 \(index)", value: "\(index)",
                                    icon: UIImage(systemName: index % 2 == 0 ? "circle" : "square"),
                                    inSection: .singleSelect("可滚动列表", index == 1))
            }
            scrolling.sheetConfig.openSectionTitle = true
            scrolling.sheetConfig.maximumListHeight = 240   // 固定的列表可视高度
            scrolling.sheetConfig.cellIconBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.10)
            scrolling.showsConfirmButton = true
            scrolling.selectAction { [weak self] selections in
                self?.record("滚动列表提交：\(selections.map(\.text).joined(separator: "、"))")
            }
            popover = scrolling
        case 19:
            let sheet = BoneDrawerSheetView(title: "玻璃遮罩",
                                            message: "背后内容被虚化；不透明度单独控制压暗程度，两者可以自由组合。")
            sheet.addButton(text: "切换玻璃（开 / 关）", icon: UIImage(systemName: "aqi.medium"),
                            dismissesPopover: false) { [weak self] in
                guard let self, let current = self.currentPopover else { return }
                current.configuration.appearance.backdropGlass.toggle()
                self.record(current.configuration.appearance.backdropGlass ? "玻璃遮罩：开" : "玻璃遮罩：关")
            }
            for opacity in [CGFloat(0), 0.12, 0.32] {
                let text = opacity == 0 ? "不透明度 0（纯模糊）" : "不透明度 \(opacity)"
                sheet.addButton(text: text, dismissesPopover: false) { [weak self] in
                    self?.setBackdropOpacity(opacity)
                }
            }
            sheet.configuration.showsBackdrop = true
            sheet.configuration.appearance.backdropGlass = true
            popover = sheet
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
        // "自动"不覆盖外观，让各预设自带默认样式生效（如底部 sheet 的阅读器默认）。
        if selectedStyle != 0 {
            applyAppearance(to: popover)
        }
        if let alert = popover as? BoneAlertView {
            if let alignment = selectedTitleAlignment { alert.titleAlignment = alignment }
            alert.titleLabel.accessibilityIdentifier = "popover-title"
            alert.messageLabel.accessibilityIdentifier = "popover-message"
            alert.cancelButton.accessibilityIdentifier = "popover-cancel"
            alert.confirmButton.accessibilityIdentifier = "popover-confirm"
        } else if let sheet = popover as? BoneDrawerSheetView {
            if let alignment = selectedTitleAlignment { sheet.titleAlignment = alignment }
            sheet.titleLabel.accessibilityIdentifier = "popover-title"
            sheet.messageLabel.accessibilityIdentifier = "popover-message"
        } else if let toast = popover as? BoneToastView {
            toast.messageLabel.accessibilityIdentifier = "toast-message"
            toast.imageView.accessibilityIdentifier = "toast-image"
            toast.loadingIndicator.accessibilityIdentifier = "toast-loading"
        }
        applyBehavior(to: popover)
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
        // 传入导航容器时，SDK 在当前内容页内挂载，不向返回栈加入临时页面。
        popover.show(from: navigationController ?? self)
    }

    /// 场景 19 用：实时改遮罩不透明度，弹窗保持打开以便对比。
    private func setBackdropOpacity(_ value: CGFloat) {
        guard let popover = currentPopover else { return }
        popover.configuration.showsBackdrop = true
        popover.configuration.appearance.backdropOpacity = value
        record(String(format: "遮罩不透明度：%.2f", Double(value)))
    }

    /// 首页的遮罩/穿透选项；选「预设」时保持各预设自带默认值。
    private func applyBehavior(to popover: BonePopoverView) {
        switch backdropControl.selectedSegmentIndex {
        case 1:
            popover.configuration.showsBackdrop = true
            popover.configuration.appearance.backdropGlass = false
        case 2:
            popover.configuration.showsBackdrop = false
        case 3:
            popover.configuration.showsBackdrop = true
            popover.configuration.appearance.backdropGlass = true
        default:
            break
        }
        if penetrationControl.selectedSegmentIndex != 0 {
            popover.configuration.allowsEventPenetration = penetrationControl.selectedSegmentIndex == 1
        }
    }

    private func toggleContentStyle() {
        guard let sheet = currentPopover as? BoneDrawerSheetView else { return }
        let expanded = sheet.sheetConfig.cellHeight == 55
        var style = sheet.configuration.contentStyle
        style.titleFont = .systemFont(ofSize: expanded ? 24 : 17, weight: .semibold)
        style.messageFont = .systemFont(ofSize: expanded ? 19 : 14)
        style.titleToContentSpacing = expanded ? 20 : 14
        style.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0,
                                                      bottom: expanded ? 32 : 20, trailing: 0)
        sheet.configuration.contentStyle = style
        var list = sheet.sheetConfig
        list.fontSize = .systemFont(ofSize: expanded ? 20 : 16, weight: .bold)
        list.cellHeight = expanded ? 72 : 55
        list.listTopSpacing = expanded ? 24 : 16
        sheet.sheetConfig = list
    }

    private func applyAppearance(to popover: BonePopoverView) {
        var value = appearance
        if popover is BoneDrawerSheetView {
            if selectedStyle == 0 {
                value = PopoverConfiguration.bottomSheet.appearance
                value.backgroundColor = .systemGroupedBackground
            }
            value.showsGrabber = true
            value.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        popover.configuration.appearance = value
    }

    private func record(_ result: String) {
        lastResult = result
        resultLabel.text = result
        // 轻提示一下，确认回调确实触发。
        resultLabel.alpha = 0.35
        UIView.animate(withDuration: 0.25) { self.resultLabel.alpha = 1 }
    }
}
