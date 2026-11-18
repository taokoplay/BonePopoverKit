import UIKit

/// 从来源控件附近展开的紧凑菜单，支持分组、图标、选中、禁用与危险操作。
/// 普通项默认先关闭再回调；`dismissesPopover: false` 可用于即时切换。
@MainActor
open class BoneMenuView: BonePopoverView {
    public enum ItemStyle {
        case `default`
        case highlighted
        case destructive
    }

    private struct MenuItem {
        var title: String
        var icon: UIImage?
        var style: ItemStyle
        var isEnabled: Bool
        var isSelected: Bool
        var dismissesPopover: Bool
        var accessibilityIdentifier: String?
        var callback: (() -> Void)?
    }

    private struct Section {
        var title: String
        var items: [MenuItem]
    }

    let tableView = UITableView(frame: .zero, style: .plain)
    private weak var anchorView: UIView?
    private var sourceRect: CGRect?
    private var lastResolvedAnchor: CGRect?
    private var sections: [Section] = []
    private static let cellIdentifier = "menu.item"

    /// 使用来源视图当前的 bounds；之后旋转或重新布局时同步转换坐标。
    public init(anchorView: UIView) {
        self.anchorView = anchorView
        super.init(nibName: nil, bundle: nil)
        configuration = .menu
        // 表格负责限高后的滚动，外层不再重复滚动。
        configuration.scrollsOverflow = false
    }

    /// 从来源视图中的一个局部矩形旁边展开。
    public init(anchorRect: CGRect, in sourceView: UIView) {
        self.anchorView = sourceView
        self.sourceRect = anchorRect
        super.init(nibName: nil, bundle: nil)
        configuration = .menu
        configuration.scrollsOverflow = false
    }

    /// 更新局部锚点；nil 恢复使用来源视图的当前 bounds。
    public func updateAnchorRect(_ rect: CGRect?) {
        sourceRect = rect
        invalidatePopoverLayout()
    }

    /// 同名分区合并为一组；未指定时为默认的无标题组。
    /// `isSelected` 是展示状态，由宿主在回调中更新，不自动作为单选或多选提交。
    public func addItem(title: String, icon: UIImage? = nil,
                        style: ItemStyle = .default,
                        isEnabled: Bool = true,
                        isSelected: Bool = false,
                        inSection sectionTitle: String? = nil,
                        dismissesPopover: Bool = true,
                        accessibilityIdentifier: String? = nil,
                        callback: (() -> Void)? = nil) {
        let sectionName = sectionTitle ?? ""
        let item = MenuItem(title: title, icon: icon, style: style,
                            isEnabled: isEnabled, isSelected: isSelected,
                            dismissesPopover: dismissesPopover,
                            accessibilityIdentifier: accessibilityIdentifier, callback: callback)
        if let index = sections.firstIndex(where: { $0.title == sectionName }) {
            sections[index].items.append(item)
        } else {
            sections.append(Section(title: sectionName, items: [item]))
        }
        reloadMenu()
    }

    public func setItemSelected(_ selected: Bool, at indexPath: IndexPath) {
        guard contains(indexPath) else { return }
        sections[indexPath.section].items[indexPath.row].isSelected = selected
        reloadMenu()
    }

    public func setItemEnabled(_ enabled: Bool, at indexPath: IndexPath) {
        guard contains(indexPath) else { return }
        sections[indexPath.section].items[indexPath.row].isEnabled = enabled
        reloadMenu()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.contentInset = .zero
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.sectionHeaderTopPadding = 0
        tableView.showsVerticalScrollIndicator = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.accessibilityIdentifier = "menu-table"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
        setContentView(tableView)
        applyContentStyle()
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 最终高度还会受锚点上/下方空间限制，用实际视口决定滚动开关。
        tableView.isScrollEnabled = menuHeight(for: tableView.bounds.width) > tableView.bounds.height + 0.5
    }

    open override func applyContentStyle() {
        guard isViewLoaded else { return }
        reloadMenu()
    }

    override func resolvedPopoverLayout(in hostView: UIView) -> PopoverLayout {
        var layout = super.resolvedPopoverLayout(in: hostView)
        if let anchorView, let sourceWindow = anchorView.window, let targetWindow = hostView.window,
           sourceWindow === targetWindow
            || (sourceWindow.windowScene != nil && sourceWindow.windowScene === targetWindow.windowScene) {
            lastResolvedAnchor = anchorView.convert(sourceRect ?? anchorView.bounds, to: hostView)
        }
        if let lastResolvedAnchor { layout.anchorRect = lastResolvedAnchor }
        return layout
    }

    open override func preferredPopoverSize(fitting availableSize: CGSize) -> CGSize {
        loadViewIfNeeded()
        if preferredContentSize.height > 0 { return preferredContentSize }
        // Host 已按 width / maximumWidth 约束传入宽度，不能再次计算 fraction。
        let width: CGFloat
        if case .content = configuration.layout.width { width = min(260, max(0, availableSize.width)) }
        else { width = max(0, availableSize.width) }
        return CGSize(width: width, height: menuHeight(for: width))
    }

    open override func notificationHidden(type: CLPopoverDismissType) {
        lastResolvedAnchor = nil
        super.notificationHidden(type: type)
    }

    private var itemFont: UIFont {
        let style = configuration.contentStyle
        return style.font(style.buttonFont, textStyle: .body, traits: traitCollection)
    }

    private var headerFont: UIFont {
        let style = configuration.contentStyle
        return style.font(style.titleFont, textStyle: .caption1, traits: traitCollection)
    }

    private func contains(_ indexPath: IndexPath) -> Bool {
        sections.indices.contains(indexPath.section)
            && sections[indexPath.section].items.indices.contains(indexPath.row)
    }

    private func rowHeight(for item: MenuItem, width: CGFloat) -> CGFloat {
        let insets = configuration.contentStyle.resolvedButtonContentInsets
        let textWidth = max(1, width - insets.leading - insets.trailing
                               - (item.icon == nil ? 0 : 34) - (item.isSelected ? 32 : 0))
        let rect = (item.title as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: itemFont], context: nil)
        return max(48, ceil(rect.height) + insets.top + insets.bottom)
    }

    private func headerHeight(for section: Section) -> CGFloat {
        section.title.isEmpty ? 0 : max(28, ceil(headerFont.lineHeight) + 12)
    }

    private func menuHeight(for width: CGFloat) -> CGFloat {
        sections.reduce(CGFloat.zero) { result, section in
            result + headerHeight(for: section)
                + section.items.reduce(CGFloat.zero) { $0 + rowHeight(for: $1, width: width) }
        }
    }

    private func reloadMenu() {
        guard isViewLoaded else { return }
        tableView.reloadData()
        invalidatePopoverLayout()
    }

    private func textColor(for style: ItemStyle) -> UIColor {
        switch style {
        case .default: return .label
        case .highlighted: return view.tintColor
        case .destructive: return .systemRed
        }
    }

    private func configure(_ cell: UITableViewCell, with item: MenuItem, at indexPath: IndexPath) {
        let color: UIColor = item.isEnabled ? textColor(for: item.style) : .tertiaryLabel
        var content = UIListContentConfiguration.cell()
        content.text = item.title
        content.textProperties.font = itemFont
        // 字体已由统一样式按当前 traits 缩放，避免 UIKit 再缩放一次。
        content.textProperties.adjustsFontForContentSizeCategory = false
        content.textProperties.numberOfLines = 0
        content.textProperties.color = color
        content.image = item.icon.map { $0.renderingMode == .alwaysOriginal
            ? $0 : $0.withRenderingMode(.alwaysTemplate) }
        content.imageProperties.tintColor = color
        content.imageProperties.maximumSize = CGSize(width: 22, height: 22)
        content.imageToTextPadding = 12
        content.directionalLayoutMargins = configuration.contentStyle.resolvedButtonContentInsets
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        cell.selectionStyle = item.isEnabled ? .default : .none
        cell.accessoryType = item.isSelected ? .checkmark : .none
        cell.tintColor = item.isEnabled ? view.tintColor : .tertiaryLabel
        cell.isUserInteractionEnabled = item.isEnabled
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = item.title
        cell.accessibilityIdentifier = item.accessibilityIdentifier
            ?? "menu-item-\(indexPath.section)-\(indexPath.row)"
        cell.accessibilityTraits = item.isEnabled ? .button : [.button, .notEnabled]
        if item.isSelected { cell.accessibilityTraits.insert(.selected) }
        cell.accessibilityValue = item.isSelected ? "已选中" : nil
    }
}

extension BoneMenuView: UITableViewDataSource, UITableViewDelegate {
    public func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        rowHeight(for: sections[indexPath.section].items[indexPath.row], width: tableView.bounds.width)
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        max(.leastNormalMagnitude, headerHeight(for: sections[section]))
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = sections[section].title
        guard !title.isEmpty else { return nil }
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = title
        label.font = headerFont
        label.textColor = configuration.contentStyle.titleColor
        label.textAlignment = configuration.contentStyle.titleAlignment
        label.accessibilityTraits.insert(.header)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        return container
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
        configure(cell, with: sections[indexPath.section].items[indexPath.row], at: indexPath)
        return cell
    }

    public func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        sections[indexPath.section].items[indexPath.row].isEnabled ? indexPath : nil
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: false) }
        guard contains(indexPath), presentationState == .presented || presentationState == .presenting else { return }
        let item = sections[indexPath.section].items[indexPath.row]
        guard item.isEnabled else { return }
        if item.dismissesPopover {
            dismissPopover(completion: { item.callback?() })
        } else {
            item.callback?()
        }
    }
}
