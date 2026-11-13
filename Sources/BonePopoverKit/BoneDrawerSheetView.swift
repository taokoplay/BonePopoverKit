import UIKit

/// 抽屉式底部弹层：标题 + 抓手 + `UITableView` 分组列表。
///
/// 用法沿用阅读器旧实现：先 `init(title:)`，再用 `addButton(text:value:style:inSection:)`
/// 逐个添加行，分区的交互方式由 `SectionType` 决定：
/// - `.normal`：点击执行回调并关闭；
/// - `.singleSelect`：分区内单选，点一次切换一次，由“确定”提交；
/// - `.multipleSelect`：分区内多选，“确定”提交全部选中项；
/// - `.drag`：行可拖动排序，并按当前顺序参与提交。
///
/// 两种取结果的方式：
/// - 选择型分区（`.singleSelect` / `.multipleSelect` / `.drag`）：打开 `showsConfirmButton`，
///   点右侧按钮统一提交，结果通过 `selectAction { ... }` 回传 `[(text: String, value: String)]`；
/// - 普通分区（`.normal`）：点行直接执行该行的 `callback` 并关闭，右侧按钮保持隐藏。
@MainActor
open class BoneDrawerSheetView: BonePopoverView {
    /// 分区类型；标题同时用作分区标题文字。
    public enum SectionType: Equatable {
        case normal(String)
        case singleSelect(String, Bool)
        case multipleSelect(String, Bool)
        case drag(String)

        public var title: String {
            switch self {
            case .normal(let title), .singleSelect(let title, _),
                 .multipleSelect(let title, _), .drag(let title):
                return title
            }
        }
    }

    /// 行的视觉样式；highlight 使用 `sheetConfig.highlightColor`。
    public enum ButtonStyle {
        case `default`
        case highlight
    }

    /// 抽屉外观参数，显示前后修改都会重新布局。
    public struct SheetConfig {
        /// 是否显示分区标题文字；关闭时只保留分区之间的间距。
        public var openSectionTitle = false
        /// 分区之间的间距，默认 10 点；打开分区标题时作为标题行高度。
        public var sectionHeight: CGFloat = 10
        /// 行文字字体，默认 16 点加粗。
        public var fontSize: UIFont = .boldSystemFont(ofSize: 16)
        /// 行高，默认 55 点；文字换行时会继续增高。
        public var cellHeight: CGFloat = 55
        /// `.highlight` 行的文字颜色与选中勾选颜色，默认跟随 tintColor。
        public var highlightColor: UIColor = .tintColor
        /// 行文字对齐，默认左对齐。
        public var textAlignment: NSTextAlignment = .left
        /// 行（cell）背景色，默认 `secondarySystemGroupedBackground`（浅色为白、深色为 #1C1C1E）；
        /// 面板底色默认 `systemGroupedBackground`（浅灰），由 `configuration.appearance.backgroundColor` 控制。
        public var cellBackgroundColor: UIColor = .secondarySystemGroupedBackground
        /// 分组首尾行的圆角，默认 10 点。
        public var cellCornerRadius: CGFloat = 10
        /// 行背景与面板左右边缘的间距，默认 16 点。
        public var horizontalInset: CGFloat = 16
        /// 行之间的分隔线颜色，默认系统分隔色；每个分区最后一行不画。
        public var cellSeparatorColor: UIColor = .separator
        /// 行图标尺寸，默认 32 点；只有传了 `icon` 的行才画。
        public var cellIconSize: CGFloat = 32
        /// 行图标底板圆角，默认 9 点。
        public var cellIconCornerRadius: CGFloat = 9
        /// 行图标底板颜色，默认 `nil` 不画底板；设成浅色即可得到系统设置那种「色块 + 图标」。
        public var cellIconBackgroundColor: UIColor?
        /// 行图标着色，默认 `nil`：原色图保留颜色，模板图跟随 `highlightColor`。
        public var cellIconTint: UIColor?
        /// 图标与文字的间距，默认 12 点。
        public var cellIconSpacing: CGFloat = 12
        /// 表头左右内边距，默认 16 点；关闭按钮与右侧按钮都按此贴边，标题随之居中。
        public var headerInset: CGFloat = 16
        /// 列表最高高度，默认 500 点；超出后列表内部滚动。
        public var maximumListHeight: CGFloat = 500
        /// 标题上下留白，默认 10 点；调小则标题更贴近抓手/顶边。
        public var headerTopSpacing: CGFloat = 10
        /// 标题与列表之间的间距，默认 10 点。
        public var listTopSpacing: CGFloat = 10

        public init() {}
    }

    /// 外观参数；修改后立即重排。
    public var sheetConfig = SheetConfig() {
        didSet { rebuildRows() }
    }

    /// 当前分区是否包含需要“确定”提交的选择型分区。
    public var hasConfirmOperation: Bool {
        sections.contains { section in
            switch section.type {
            case .singleSelect(_, _), .multipleSelect(_, _), .drag(_): return true
            case .normal(_): return false
            }
        }
    }

    /// 是否包含可拖动排序的分区。
    public var hasDragOperation: Bool {
        sections.contains { if case .drag(_) = $0.type { return true } else { return false } }
    }

    /// 确认按钮文案；nil 使用“确定”。
    public var confirmTitle: String? {
        didSet { applyButtonTitles() }
    }

    /// 左上角关闭按钮的辅助功能标签；nil 使用“关闭”。
    public var closeAccessibilityLabel: String? {
        didSet { applyButtonTitles() }
    }

    /// 标题控件；字体、颜色与对齐由 `configuration.contentStyle` 刷新。
    public let titleLabel = UILabel()
    /// 标题行右侧按钮；默认显示“确定”并提交选中项，宿主可改文案、图标或自行接管点击。
    public var trailingButton: UIButton { confirmButton }
    /// 是否显示右侧按钮，默认 `false`（不设置就不出现）。
    /// 多选/单选这类选择型分区需要统一提交时再打开，点击会走 `selectAction` 并关闭。
    public var showsConfirmButton = false {
        didSet { applyTrailingButtonVisibility() }
    }
    /// 自定义右侧按钮点击行为：设置后按钮显示，且不再执行默认的“提交并关闭”，由宿主自行处理。
    public var onTrailingButtonTap: (() -> Void)? {
        didSet { applyTrailingButtonVisibility() }
    }

    private struct ButtonModel {
        var text: String
        var value: String
        /// 行首图标；nil 时不占位，行布局与旧版本一致。
        var icon: UIImage?
        var style: ButtonStyle
        var callback: (() -> Void)?
    }

    private struct Section {
        var type: SectionType
        var buttons: [ButtonModel]
    }

    private var sections: [Section] = []
    private var selectIndexPath = Set<IndexPath>()
    private var selectCallback: (([(text: String, value: String)]) -> Void)?

    private let contentStack = makePopoverStack()
    /// 仅用于复用共享排版函数；抽屉没有正文行。
    private let typographyPlaceholder = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    /// 列表本体；沿用阅读器做法，透明背景 + 分组样式 + 无系统分隔线。
    let tableView = UITableView(frame: .zero, style: .grouped)
    /// 标题行与其上下留白约束，`sheetConfig.headerTopSpacing` 变化后同步。
    private weak var headerRowView: UIView?
    private var headerTopConstraint: NSLayoutConstraint?
    private var headerBottomConstraint: NSLayoutConstraint?
    private var tableHeightConstraint: NSLayoutConstraint?
    private var cancelSizeConstraints: [NSLayoutConstraint] = []
    private var confirmSizeConstraints: [NSLayoutConstraint] = []

    /// 创建抽屉；分区与行通过 `addButton(text:value:style:inSection:)` 添加。
    public init(title: String) {
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        configuration = .bottomSheet
        // 面板用分组灰底、行用白底：与系统「设置」式分组列表一致。
        configuration.appearance.backgroundColor = .systemGroupedBackground
        configuration.appearance.showsGrabber = true
        configuration.contentStyle.titleFont = .systemFont(ofSize: 17, weight: .semibold)
        configuration.contentStyle.titleAlignment = .center
        configuration.contentStyle.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0,
                                                                          bottom: 20, trailing: 0)
        // 列表自己负责滚动，外层保持一屏内不滚动，避免嵌套滚动抢手势。
        configuration.scrollsOverflow = false
    }

    /// 提交回调：单选/多选返回选中项，拖拽分区按当前顺序返回全部。
    public func selectAction(_ callback: @escaping ([(text: String, value: String)]) -> Void) {
        selectCallback = callback
    }

    /// 添加一行。
    /// - Parameters:
    ///   - text: 行文字。
    ///   - value: 业务值，随提交结果回传。
    ///   - icon: 行首图标；传了才画，尺寸与底板参数在 `sheetConfig` 里。
    ///   - style: `.default` 或 `.highlight`。
    ///   - sectionType: 所属分区；标题相同即视为同一分区，不存在时自动创建。
    ///   - callback: `.normal` 分区点击后的业务回调；选择型分区忽略。
    public func addButton(text: String, value: String = "", icon: UIImage? = nil,
                          style: ButtonStyle = .default,
                          inSection sectionType: SectionType = .normal(""),
                          callback: (() -> Void)? = nil) {
        let model = ButtonModel(text: text, value: value, icon: icon, style: style, callback: callback)
        // 与阅读器旧实现一致：标题相同即同一个分区，初值 Bool 只影响新行的默认选中。
        if let index = sections.firstIndex(where: { $0.type.title == sectionType.title }) {
            sections[index].buttons.append(model)
            if shouldSelectNewRow(in: sectionType) {
                selectIndexPath.insert(IndexPath(row: sections[index].buttons.count - 1, section: index))
            }
        } else {
            sections.append(Section(type: sectionType, buttons: [model]))
            let sectionIndex = sections.count - 1
            if shouldSelectNewRow(in: sectionType) {
                selectIndexPath.insert(IndexPath(row: 0, section: sectionIndex))
            }
        }
        rebuildRows()
    }

    /// 单选/多选分区按 `SectionType` 的初始布尔值决定新行是否选中；拖拽分区的行始终视为选中。
    private func shouldSelectNewRow(in type: SectionType) -> Bool {
        switch type {
        case .singleSelect(_, let selected), .multipleSelect(_, let selected): return selected
        case .drag: return true
        case .normal(_): return false
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configurePopoverLabel(titleLabel)
        titleLabel.accessibilityTraits.insert(.header)
        contentStack.spacing = 0
        contentStack.addArrangedSubview(makeHeaderRow())
        contentStack.addArrangedSubview(tableView)
        contentStack.setCustomSpacing(0, after: tableView)

        confirmButton.accessibilityIdentifier = "drawer-confirm"
        confirmButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if let custom = self.onTrailingButtonTap {
                custom()
            } else {
                self.confirm()
            }
        }, for: .touchUpInside)
        cancelButton.accessibilityIdentifier = "drawer-close"
        cancelButton.accessibilityLabel = resolvedCloseLabel
        cancelButton.addAction(UIAction { [weak self] _ in self?.hidden() }, for: .touchUpInside)

        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableHeightConstraint?.isActive = true
        setContentView(contentStack)
        rebuildRows()
    }

    open override func applyContentStyle() {
        guard isViewLoaded else { return }
        let style = configuration.contentStyle
        // 标题排版复用共享逻辑；两个圆形按钮不参与，避免按钮字体与内边距被通用样式覆盖。
        applyPopoverTypography(style, title: titleLabel, message: typographyPlaceholder,
                               buttons: [], traits: traitCollection)
        contentStack.directionalLayoutMargins = style.resolvedContentInsets
        applyPopoverCloseButtonStyle(cancelButton, style: style)
        applyPopoverCircleButtonStyle(confirmButton, style: style, title: resolvedConfirmTitle)
        updateHeaderButtonSizes(style.resolvedCloseButtonSize)
        cancelButton.accessibilityLabel = resolvedCloseLabel
        rebuildRows()
    }

    // MARK: - 列表

    private func configureTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.separatorColor = .clear
        tableView.separatorInset = .zero
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.rowHeight = sheetConfig.cellHeight
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.showsVerticalScrollIndicator = false
        tableView.dragInteractionEnabled = false
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        tableView.accessibilityIdentifier = "drawer-table"
        tableView.register(BoneDrawerSheetCell.self, forCellReuseIdentifier: Self.cellIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
    }

    /// 按当前分区与行数重建列表：刷新数据、重排高度、同步滚动开关。
    func rebuildRows() {
        guard isViewLoaded else { return }
        tableView.rowHeight = sheetConfig.cellHeight
        tableView.dragInteractionEnabled = hasDragOperation
        tableView.reloadData()
        applyHeaderSpacing()
        updateTableHeight()
        applyTrailingButtonVisibility()
        refreshSelection()
        invalidatePopoverLayout()
    }

    /// 标题上下留白与「标题到列表」的间距跟随 `sheetConfig`。
    private func applyHeaderSpacing() {
        headerTopConstraint?.constant = sheetConfig.headerTopSpacing
        headerBottomConstraint?.constant = -sheetConfig.headerTopSpacing
        if let header = headerRowView {
            contentStack.setCustomSpacing(sheetConfig.listTopSpacing, after: header)
        }
    }

    /// 列表高度按分区自己算，不依赖 `contentSize`；超过 `maximumListHeight` 时内部滚动。
    private func updateTableHeight() {
        let rowHeight = sheetConfig.cellHeight
        let rows = sections.reduce(CGFloat.zero) { $0 + CGFloat($1.buttons.count) }
        let headerUnit = sectionHeaderHeight()
        let headerTotal = sections.isEmpty ? 0 : CGFloat(max(0, sections.count - 1)) * headerUnit
        let content = rows * rowHeight + headerTotal
        let limit = max(120, sheetConfig.maximumListHeight)
        tableHeightConstraint?.constant = min(content, limit)
        tableView.isScrollEnabled = content > limit + 0.5
    }

    /// 分区标题行高度：第一区不占位，打开标题时按 35 点给标题留位置。
    private func sectionHeaderHeight() -> CGFloat {
        sheetConfig.openSectionTitle ? 35 : sheetConfig.sectionHeight
    }

    /// 标题行：标题居中，左侧关闭按钮（向下箭头），右侧自定义按钮（默认“确定”）。
    private func makeHeaderRow() -> UIView {
        let header = UIView()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        // 与操作列表共用同一套向下箭头外观（iOS 26+ 液态玻璃圆圈）。
        applyPopoverCloseButtonStyle(cancelButton, style: configuration.contentStyle)
        cancelButton.accessibilityIdentifier = "drawer-close"
        cancelButton.accessibilityLabel = resolvedCloseLabel
        header.addSubview(cancelButton)

        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        // 与左侧关闭按钮同一套圆形/玻璃外观，只是内容是文字。
        applyPopoverCircleButtonStyle(confirmButton, style: configuration.contentStyle,
                                      title: resolvedConfirmTitle)
        header.addSubview(confirmButton)

        // 两个按钮共用同一尺寸常量，`contentStyle.closeButtonSize` 变化时一起更新。
        let size = configuration.contentStyle.resolvedCloseButtonSize
        cancelSizeConstraints = [
            cancelButton.widthAnchor.constraint(equalToConstant: size),
            cancelButton.heightAnchor.constraint(equalToConstant: size)
        ]
        confirmSizeConstraints = [
            confirmButton.widthAnchor.constraint(greaterThanOrEqualToConstant: size),
            confirmButton.heightAnchor.constraint(equalToConstant: size)
        ]
        let top = titleLabel.topAnchor.constraint(equalTo: header.topAnchor,
                                                  constant: sheetConfig.headerTopSpacing)
        let bottom = titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor,
                                                        constant: -sheetConfig.headerTopSpacing)
        headerTopConstraint = top
        headerBottomConstraint = bottom
        headerRowView = header
        NSLayoutConstraint.activate([top, bottom,
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor,
                                                constant: sheetConfig.headerInset + size + 8),
            titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor,
                                                 constant: -(sheetConfig.headerInset + size + 8)),
            cancelButton.topAnchor.constraint(equalTo: header.topAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: header.leadingAnchor,
                                                  constant: sheetConfig.headerInset),
            confirmButton.trailingAnchor.constraint(equalTo: header.trailingAnchor,
                                                    constant: -sheetConfig.headerInset),
            confirmButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor)
        ] + cancelSizeConstraints + confirmSizeConstraints)
        return header
    }

    /// 关闭按钮与右侧按钮保持同一尺寸与圆角；`contentStyle.closeButtonSize` 改变后同步。
    private func updateHeaderButtonSizes(_ size: CGFloat) {
        for constraint in cancelSizeConstraints + confirmSizeConstraints
        where constraint.constant != size {
            constraint.constant = size
        }
        cancelButton.layer.cornerRadius = size / 2
        confirmButton.layer.cornerRadius = size / 2
    }

    /// 右侧按钮默认隐藏；只有显式打开 `showsConfirmButton` 或接管点击时才出现。
    private func applyTrailingButtonVisibility() {
        guard isViewLoaded else { return }
        confirmButton.isHidden = !(showsConfirmButton || onTrailingButtonTap != nil)
    }

    /// 勾选状态跟着 `selectIndexPath` 走；`.drag` 分区按顺序全部勾上。
    func refreshSelection() {
        guard isViewLoaded else { return }
        tableView.reloadData()
    }

    /// 确认：拖拽分区按当前顺序全部回传，其余分区只回传选中项。
    private func confirm() {
        var result: [(text: String, value: String)] = []
        for (sectionIndex, section) in sections.enumerated() {
            switch section.type {
            case .drag(_):
                result.append(contentsOf: section.buttons.map { (text: $0.text, value: $0.value) })
            case .normal(_), .singleSelect(_, _), .multipleSelect(_, _):
                for (rowIndex, button) in section.buttons.enumerated()
                where selectIndexPath.contains(IndexPath(row: rowIndex, section: sectionIndex)) {
                    result.append((text: button.text, value: button.value))
                }
            }
        }
        let callback = selectCallback
        hidden { callback?(result) }
    }

    private var resolvedConfirmTitle: String {
        if let text = confirmTitle, !text.isEmpty { return text }
        return "确定"
    }

    private var resolvedCloseLabel: String {
        if let text = closeAccessibilityLabel, !text.isEmpty { return text }
        return "关闭"
    }

    private func applyButtonTitles() {
        guard isViewLoaded else { return }
        applyPopoverCircleButtonStyle(confirmButton, style: configuration.contentStyle,
                                      title: resolvedConfirmTitle)
        applyPopoverCircleButtonStyle(cancelButton, style: configuration.contentStyle)
        cancelButton.accessibilityLabel = resolvedCloseLabel
        invalidatePopoverLayout()
    }

    private static let cellIdentifier = "drawer.row"

    private func isDragSection(_ type: SectionType) -> Bool {
        if case .drag(_) = type { return true }
        return false
    }

    private func accessorySymbol(for type: SectionType) -> String {
        switch type {
        case .drag(_): return "line.3.horizontal"
        case .singleSelect(_, _), .multipleSelect(_, _): return "checkmark"
        case .normal(_): return "checkmark"
        }
    }

    /// 行在分组中的位置决定圆角方向。
    private func roundStyle(for indexPath: IndexPath) -> BoneDrawerSheetCell.RoundStyle {
        let count = sections[indexPath.section].buttons.count
        let isFirst = indexPath.row == 0
        let isLast = indexPath.row == count - 1
        if isFirst && isLast { return .all }
        if isFirst { return .top }
        if isLast { return .bottom }
        return .none
    }

    private func cellConfiguration(at indexPath: IndexPath) -> BoneDrawerSheetCell.Configuration {
        let section = sections[indexPath.section]
        let model = section.buttons[indexPath.row]
        let type = section.type
        return BoneDrawerSheetCell.Configuration(
            text: model.text,
            textColor: model.style == .highlight ? sheetConfig.highlightColor : .label,
            font: sheetConfig.fontSize,
            textAlignment: sheetConfig.textAlignment,
            cellBackgroundColor: sheetConfig.cellBackgroundColor,
            separatorColor: sheetConfig.cellSeparatorColor,
            cornerRadius: sheetConfig.cellCornerRadius,
            showsSeparator: indexPath.row != section.buttons.count - 1,
            horizontalInset: sheetConfig.horizontalInset,
            icon: model.icon,
            iconBoxColor: sheetConfig.cellIconBackgroundColor,
            iconTint: model.icon == nil ? sheetConfig.highlightColor
                : (sheetConfig.cellIconTint ?? sheetConfig.highlightColor),
            iconSize: sheetConfig.cellIconSize,
            iconCornerRadius: sheetConfig.cellIconCornerRadius,
            iconSpacing: sheetConfig.cellIconSpacing,
            accessoryImage: UIImage(systemName: accessorySymbol(for: type)),
            accessoryTint: sheetConfig.highlightColor
        )
    }

    private func isSelectedRow(at indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section].type {
        case .drag(_): return true
        case .normal(_): return false
        case .singleSelect(_, _), .multipleSelect(_, _):
            return selectIndexPath.contains(indexPath)
        }
    }

    private func handleTap(indexPath: IndexPath) {
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].buttons.count else { return }
        let section = sections[indexPath.section]
        let model = section.buttons[indexPath.row]
        switch section.type {
        case .normal(_):
            hidden { model.callback?() }
        case .singleSelect(_, _):
            selectIndexPath = selectIndexPath.filter { $0.section != indexPath.section }
            selectIndexPath.insert(indexPath)
            refreshSelection()
        case .multipleSelect(_, _):
            if selectIndexPath.contains(indexPath) {
                selectIndexPath.remove(indexPath)
            } else {
                selectIndexPath.insert(indexPath)
            }
            refreshSelection()
        case .drag(_):
            break
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension BoneDrawerSheetView: UITableViewDataSource, UITableViewDelegate {
    public func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].buttons.count
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 0.01 : sectionHeaderHeight()
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0.01
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard sheetConfig.openSectionTitle, section > 0 else { return nil }
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = sections[section].type.title
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor,
                                           constant: sheetConfig.horizontalInset + 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor,
                                            constant: -(sheetConfig.horizontalInset + 16))
        ])
        return container
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
        guard let row = cell as? BoneDrawerSheetCell else { return cell }
        row.sheetInsets = (horizontalInset: sheetConfig.horizontalInset,
                           iconSize: sheetConfig.cellIconSize,
                           iconSpacing: sheetConfig.cellIconSpacing)
        row.apply(cellConfiguration(at: indexPath))
        row.roundStyle = roundStyle(for: indexPath)
        row.rowIdentifier = "drawer-row-\(indexPath.section)-\(indexPath.row)"
        row.accessibilityLabel = sections[indexPath.section].buttons[indexPath.row].text
        row.accessibilityTraits = .button
        row.isSelected = isSelectedRow(at: indexPath)
        return row
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: false) }
        handleTap(indexPath: indexPath)
    }
}

// MARK: - 拖动排序

extension BoneDrawerSheetView: UITableViewDragDelegate, UITableViewDropDelegate {
    public func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession,
                          at indexPath: IndexPath) -> [UIDragItem] {
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].buttons.count,
              isDragSection(sections[indexPath.section].type) else { return [] }
        let text = sections[indexPath.section].buttons[indexPath.row].text
        let item = UIDragItem(itemProvider: NSItemProvider(object: text as NSString))
        item.localObject = indexPath as NSIndexPath
        return [item]
    }

    public func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        session.localDragSession != nil
    }

    public func tableView(_ tableView: UITableView,
                          dropSessionDidUpdate session: UIDropSession,
                          withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        guard let destination = destinationIndexPath, destination.section < sections.count,
              isDragSection(sections[destination.section].type) else {
            return UITableViewDropProposal(operation: .cancel)
        }
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    public func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let destination = coordinator.destinationIndexPath,
              destination.section < sections.count,
              isDragSection(sections[destination.section].type) else { return }
        for item in coordinator.items {
            guard let source = item.sourceIndexPath, source.section == destination.section,
                  source != destination else { continue }
            let moved = sections[source.section].buttons.remove(at: source.row)
            sections[destination.section].buttons
                .insert(moved, at: min(destination.row, sections[destination.section].buttons.count))
            tableView.performBatchUpdates {
                tableView.moveRow(at: source, to: destination)
            } completion: { [weak self] _ in
                self?.refreshSelection()
            }
        }
    }
}
