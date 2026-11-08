import UIKit
import BonePopoverKit

/// A playground for combinations that need actual touches rather than screenshots.
final class InteractionDemoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var settings = PopoverConfiguration()
    private weak var currentPopover: BoneAlertView?
    private var showsBottom = false
    private var count = 0
    private var status = "选择展示方式，再滑动标题区域或点击弹窗外部。"
    private let toggleTitles = ["显示背景遮罩", "点击外部关闭", "外部触摸穿透", "穿透时自动关闭", "允许滑动关闭"]
    private let directions: [(String, PopoverSwipeDirection)] = [
        ("自动", .automatic), ("四向", .all), ("左右", .horizontal), ("上下", .vertical),
        ("仅向上", .up), ("仅向下", .down), ("仅向左", .left), ("仅向右", .right), ("禁用", .none)
    ]

    init() {
        super.init(nibName: nil, bundle: nil)
        settings.allowedSwipeDirections = .all
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "关闭交互"
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.accessibilityIdentifier = "interaction-list"
        let names = ["透明背景外部关闭", "拦截外部点击", "穿透不关闭", "穿透并关闭", "四向滑动", "仅左滑", "高阈值滑动"]
        let actions = names.enumerated().map { index, name in
            UIAction(title: name) { [weak self] _ in self?.applyPreset(index) }
        }
        let menu = UIBarButtonItem(title: "交互方案", menu: UIMenu(children: actions))
        menu.accessibilityIdentifier = "interaction-presets"
        navigationItem.rightBarButtonItem = menu
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent { currentPopover?.dismissPopover(animated: false) }
    }

    func numberOfSections(in tableView: UITableView) -> Int { 4 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        [3, toggleTitles.count, 1, 1][section]
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["体验", "外部触摸与背景", "滑动方向", "关闭距离"][section]
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return status
        case 1: return "穿透开启后，点击可以传给底层页面；是否同时关闭由“穿透时自动关闭”决定。"
        case 2: return "拖动标题或说明区域。自动方向跟随弹窗位置；居中弹窗开启滑动后自动支持四向。"
        default: return "慢速拖动需超过所选距离；快速滑动会结合松手速度判断。滑动不足或反向收回会回弹。"
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        if indexPath.section == 0 {
            cell.textLabel?.text = ["底层点击次数：\(count)", "展示居中弹窗", "展示底部弹窗"][indexPath.row]
            cell.accessibilityIdentifier = ["interaction-counter", "interaction-center", "interaction-bottom"][indexPath.row]
            cell.accessoryType = indexPath.row == 0 ? .none : .disclosureIndicator
        } else if indexPath.section == 1 {
            cell.textLabel?.text = toggleTitles[indexPath.row]
            let control = UISwitch()
            control.isOn = toggleValue(indexPath.row)
            control.accessibilityLabel = toggleTitles[indexPath.row]
            control.accessibilityIdentifier = "interaction-setting-\(indexPath.row)"
            control.addAction(UIAction { [weak self, weak control] _ in
                guard let self, let control else { return }
                self.setToggle(indexPath.row, value: control.isOn)
                self.updateVisiblePopover()
            }, for: .valueChanged)
            cell.accessoryView = control
            cell.selectionStyle = .none
        } else if indexPath.section == 2 {
            cell.textLabel?.text = "允许方向"
            let button = UIButton(type: .system)
            let selected = directions.first { $0.1 == settings.allowedSwipeDirections }?.0 ?? "自定义"
            button.setTitle(selected, for: .normal)
            button.accessibilityIdentifier = "interaction-directions"
            button.menu = UIMenu(children: directions.map { name, direction in
                UIAction(title: name, state: settings.allowedSwipeDirections == direction ? .on : .off) { [weak self] _ in
                    self?.settings.allowedSwipeDirections = direction
                    self?.updateVisiblePopover()
                    self?.tableView.reloadData()
                }
            })
            button.showsMenuAsPrimaryAction = true
            button.sizeToFit()
            cell.accessoryView = button
        } else {
            let control = UISegmentedControl(items: ["50 点", "100 点", "200 点"])
            control.selectedSegmentIndex = settings.swipeThreshold == 50 ? 0 : settings.swipeThreshold == 200 ? 2 : 1
            control.accessibilityIdentifier = "interaction-threshold"
            control.addAction(UIAction { [weak self, weak control] _ in
                guard let self, let control else { return }
                self.settings.swipeThreshold = [CGFloat(50), 100, 200][control.selectedSegmentIndex]
                self.updateVisiblePopover()
            }, for: .valueChanged)
            cell.contentView.addSubview(control)
            control.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                control.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                control.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                control.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
            ])
            cell.selectionStyle = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else { return }
        if indexPath.row == 0 {
            count += 1
            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            guard currentPopover == nil else { return }
            showPopover(bottom: indexPath.row == 2)
        }
    }

    private func toggleValue(_ index: Int) -> Bool {
        switch index {
        case 0: return settings.showsBackdrop
        case 1: return settings.dismissOnBackdropTap
        case 2: return settings.allowsEventPenetration
        case 3: return settings.autoHideWhenPenetrated
        default: return settings.allowsDragToDismiss
        }
    }
    private func setToggle(_ index: Int, value: Bool) {
        switch index {
        case 0: settings.showsBackdrop = value
        case 1: settings.dismissOnBackdropTap = value
        case 2: settings.allowsEventPenetration = value
        case 3: settings.autoHideWhenPenetrated = value
        default: settings.allowsDragToDismiss = value
        }
    }
    private func configuration(bottom: Bool) -> PopoverConfiguration {
        var value = settings
        let preset = bottom ? PopoverConfiguration.bottomSheet : .centerDialog
        value.layout = preset.layout
        value.animation = preset.animation
        value.appearance.showsGrabber = bottom
        return value
    }
    private func updateVisiblePopover() {
        currentPopover?.configuration = configuration(bottom: showsBottom)
    }
    private func applyPreset(_ index: Int) {
        settings = PopoverConfiguration()
        settings.allowedSwipeDirections = .all
        switch index {
        case 0: settings.showsBackdrop = false
        case 1: settings.dismissOnBackdropTap = false
        case 2, 3:
            settings.showsBackdrop = false
            settings.allowsEventPenetration = true
            settings.autoHideWhenPenetrated = index == 3
        case 5: settings.allowedSwipeDirections = .left
        case 6: settings.swipeThreshold = 200
        default: break
        }
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
        tableView.reloadData()
        updateVisiblePopover()
    }
    private func showPopover(bottom: Bool) {
        showsBottom = bottom
        let alert = BoneAlertView(title: "滑动或点外部关闭", message: "拖动这段说明或标题测试滑动。\n外部点击可用顶部的底层计数验证。") {}
        alert.configuration = configuration(bottom: bottom)
        alert.titleLabel.accessibilityIdentifier = "interaction-title"
        alert.baseView.accessibilityIdentifier = "interaction-content"
        alert.onDidShow = { [weak alert] in alert?.view.accessibilityIdentifier = "interaction-ready" }
        alert.notificationDismissComplete = { [weak self] in
            self?.currentPopover = nil
            self?.status = "弹窗已关闭；可更换交互方案继续体验。"
        }
        currentPopover = alert
        if !alert.show(from: self) { currentPopover = nil }
    }
}
