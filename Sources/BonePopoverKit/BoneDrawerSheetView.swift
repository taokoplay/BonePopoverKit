import UIKit

/// 默认底部操作列表：标题 + 抓手 + `UITableView` 分组列表，统一承载普通动作与选择/排序。
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
        case destructive
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
        /// 标题与列表之间的间距，默认 16 点。
        public var listTopSpacing: CGFloat = 16

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
    /// 可选说明文字，字体、颜色和对齐由 `configuration.contentStyle` 管理。
    public let messageLabel = UILabel()
    /// 左侧关闭按钮，可定制图标、尺寸和辅助功能属性。
    public var closeButton: UIButton { cancelButton }
    public var titleAlignment: NSTextAlignment {
        get { configuration.contentStyle.titleAlignment }
        set { configuration.contentStyle.titleAlignment = newValue }
    }
    public var showsCloseButton = true {
        didSet {
            guard isViewLoaded else { return }
            cancelButton.isHidden = !showsCloseButton
            applyHeaderSpacing()
            invalidatePopoverLayout()
        }
    }
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
        var dismissesPopover: Bool
        var accessibilityIdentifier: String?
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
    private let messageRow = UIView()
    private var messageLeadingConstraint: NSLayoutConstraint?
    private var messageTrailingConstraint: NSLayoutConstraint?
    private let confirmButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    /// 列表本体；沿用阅读器做法，透明背景 + 分组样式 + 无系统分隔线。
    let tableView = UITableView(frame: .zero, style: .grouped)
    /// 标题行与其上下留白约束，`sheetConfig.headerTopSpacing` 变化后同步。
    private weak var headerRowView: UIView?
    private var headerTopConstraint: NSLayoutConstraint?
    private var headerBottomConstraint: NSLayoutConstraint?
    private var headerMinimumHeightConstraint: NSLayoutConstraint?
    private var titleLeadingConstraint: NSLayoutConstraint?
    private var titleTrailingConstraint: NSLayoutConstraint?
    private var closeLeadingConstraint: NSLayoutConstraint?
    private var confirmTrailingConstraint: NSLayoutConstraint?
    private var tableHeightConstraint: NSLayoutConstraint?
    private var cancelSizeConstraints: [NSLayoutConstraint] = []
    private var confirmSizeConstraints: [NSLayoutConstraint] = []

    /// 创建抽屉；分区与行通过 `addButton(text:value:style:inSection:)` 添加。
    public init(title: String, message: String? = nil) {
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        messageLabel.text = message
        configuration = .bottomSheet
        // 面板用分组灰底、行用白底：与系统「设置」式分组列表一致。
        configuration.appearance.backgroundColor = .systemGroupedBackground
        configuration.appearance.showsGrabber = true
        configuration.contentStyle.titleFont = .systemFont(ofSize: 17, weight: .semibold)
        configuration.contentStyle.messageFont = .systemFont(ofSize: 14)
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

    /// 添加动作或选择项；未指定分区时是点击后关闭的普通动作。
    /// `dismissesPopover = false` 使普通动作回调后保持打开；选择型分区继续由“确定”提交。
    /// `accessibilityIdentifier` 未设置时使用 `drawer-row-分区-行`。
    public func addButton(text: String, value: String = "", icon: UIImage? = nil,
                          style: ButtonStyle = .default,
                          inSection sectionType: SectionType = .normal(""),
                          dismissesPopover: Bool = true,
                          accessibilityIdentifier: String? = nil,
                          callback: (() -> Void)? = nil) {
        let model = ButtonModel(text: text, value: value, icon: icon, style: style,
                                dismissesPopover: dismissesPopover,
                                accessibilityIdentifier: accessibilityIdentifier, callback: callback)
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
        configureMessageRow()
        contentStack.addArrangedSubview(messageRow)
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
        cancelButton.isHidden = !showsCloseButton
        cancelButton.addAction(UIAction { [weak self] _ in self?.hidden() }, for: .touchUpInside)

        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableHeightConstraint?.isActive = true
        setContentView(contentStack)
        applyContentStyle()
    }

    open override func applyContentStyle() {
        guard isViewLoaded else { return }
        let style = configuration.contentStyle
        // 标题排版复用共享逻辑；两个圆形按钮不参与，避免按钮字体与内边距被通用样式覆盖。
        applyPopoverTypography(style, title: titleLabel, message: messageLabel,
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
        // 统一在 refreshSelection 中刷新可复用行。
        applyHeaderSpacing()
        updateTableHeight()
        applyTrailingButtonVisibility()
        refreshSelection()
        invalidatePopoverLayout()
    }

    private func configureMessageRow() {
        configurePopoverLabel(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageRow.addSubview(messageLabel)
        messageLeadingConstraint = messageLabel.leadingAnchor.constraint(equalTo: messageRow.leadingAnchor,
                                                                          constant: sheetConfig.headerInset)
        messageTrailingConstraint = messageLabel.trailingAnchor.constraint(equalTo: messageRow.trailingAnchor,
                                                                            constant: -sheetConfig.headerInset)
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: messageRow.topAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: messageRow.bottomAnchor)
        ] + [messageLeadingConstraint, messageTrailingConstraint].compactMap { $0 })
    }

    /// 表头、可选说明与列表统一使用当前间距设置。
    private func applyHeaderSpacing() {
        let inset = sheetConfig.headerInset
        let size = configuration.contentStyle.resolvedCloseButtonSize
        let hasTrailing = showsConfirmButton || onTrailingButtonTap != nil
        var leadingReserve = showsCloseButton ? size + 8 : 0
        var trailingReserve = hasTrailing ? max(size + 8, confirmButton.intrinsicContentSize.width) + 8 : 0
        if configuration.contentStyle.titleAlignment == .center {
            leadingReserve = max(leadingReserve, trailingReserve)
            trailingReserve = leadingReserve
            // 内容区可使用不对称边距，居中标题仍围绕整个面板保持对称。
            let insets = configuration.contentStyle.resolvedContentInsets
            leadingReserve += max(0, insets.trailing - insets.leading)
            trailingReserve += max(0, insets.leading - insets.trailing)
        }
        headerTopConstraint?.constant = sheetConfig.headerTopSpacing
        headerBottomConstraint?.constant = -sheetConfig.headerTopSpacing
        titleLeadingConstraint?.constant = inset + leadingReserve
        titleTrailingConstraint?.constant = -(inset + trailingReserve)
        closeLeadingConstraint?.constant = inset
        confirmTrailingConstraint?.constant = -inset
        messageLeadingConstraint?.constant = inset
        messageTrailingConstraint?.constant = -inset
        let hasMessage = !(messageLabel.text?.isEmpty ?? true)
        messageRow.isHidden = !hasMessage
        if let header = headerRowView {
            contentStack.setCustomSpacing(hasMessage ? configuration.contentStyle.resolvedTitleSpacing
                                                    : sheetConfig.listTopSpacing, after: header)
        }
        if contentStack.arrangedSubviews.contains(messageRow) {
            contentStack.setCustomSpacing(sheetConfig.listTopSpacing, after: messageRow)
        }
    }

    /// 列表高度按分区自己算，不依赖 `contentSize`；超过 `maximumListHeight` 时内部滚动。
    private func updateTableHeight() {
        let rowHeight = sheetConfig.cellHeight
        let rows = sections.reduce(CGFloat.zero) { $0 + CGFloat($1.buttons.count) }
        // 每个分区的标题高度单独算：没标题的分区不占标题位，只用普通间距。
        let headerTotal = sections.indices.reduce(CGFloat.zero) { $0 + headerHeight(forSection: $1) }
        let content = rows * rowHeight + headerTotal
        let limit = max(120, sheetConfig.maximumListHeight)
        tableHeightConstraint?.constant = min(content, limit)
        tableView.isScrollEnabled = content > limit + 0.5
    }

    /// 分区标题行高度：第一区不占位；打开标题时为 35 点，**分区没有标题时自动收缩成普通间距**。
    private func headerHeight(forSection section: Int) -> CGFloat {
        guard section > 0, section < sections.count else { return section == 0 ? 0.01 : 0 }
        guard sheetConfig.openSectionTitle else { return sheetConfig.sectionHeight }
        return sections[section].type.title.isEmpty ? sheetConfig.sectionHeight : 35
    }

    /// 标题行：标题居中，左侧关闭按钮（向下箭头），右侧自定义按钮（默认“确定”）。
    private func makeHeaderRow() -> UIView {
        let header = UIView()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        // 统一的向下箭头外观（iOS 26+ 液态玻璃圆圈）。
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
        // 文字按钮比左侧圆圈宽一些，至少留出 8 点余量。
        confirmSizeConstraints = [
            confirmButton.widthAnchor.constraint(greaterThanOrEqualToConstant: size + 8),
            confirmButton.heightAnchor.constraint(equalToConstant: size)
        ]
        let top = titleLabel.topAnchor.constraint(greaterThanOrEqualTo: header.topAnchor,
                                                  constant: sheetConfig.headerTopSpacing)
        let bottom = titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: header.bottomAnchor,
                                                        constant: -sheetConfig.headerTopSpacing)
        let minimumHeight = header.heightAnchor.constraint(greaterThanOrEqualToConstant: size)
        headerMinimumHeightConstraint = minimumHeight
        headerTopConstraint = top
        headerBottomConstraint = bottom
        headerRowView = header
        titleLeadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor)
        titleTrailingConstraint = titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor)
        closeLeadingConstraint = cancelButton.leadingAnchor.constraint(equalTo: header.leadingAnchor)
        confirmTrailingConstraint = confirmButton.trailingAnchor.constraint(equalTo: header.trailingAnchor)
        NSLayoutConstraint.activate([
            top, bottom, minimumHeight,
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            confirmButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor)
        ] + [titleLeadingConstraint, titleTrailingConstraint, closeLeadingConstraint,
             confirmTrailingConstraint].compactMap { $0 } + cancelSizeConstraints + confirmSizeConstraints)
        return header
    }

    /// 关闭按钮与右侧按钮保持同一尺寸与圆角；`contentStyle.closeButtonSize` 改变后同步。
    private func updateHeaderButtonSizes(_ size: CGFloat) {
        for constraint in cancelSizeConstraints { constraint.constant = size }
        confirmSizeConstraints.first?.constant = size + 8
        confirmSizeConstraints.last?.constant = size
        headerMinimumHeightConstraint?.constant = size
        cancelButton.layer.cornerRadius = size / 2
        confirmButton.layer.cornerRadius = size / 2
    }

    /// 右侧按钮默认隐藏；只有显式打开 `showsConfirmButton` 或接管点击时才出现。
    private func applyTrailingButtonVisibility() {
        guard isViewLoaded else { return }
        confirmButton.isHidden = !(showsConfirmButton || onTrailingButtonTap != nil)
        applyHeaderSpacing()
        invalidatePopoverLayout()
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
        applyHeaderSpacing()
        invalidatePopoverLayout()
    }

    private static let cellIdentifier = "drawer.row"

    private func isDragSection(_ type: SectionType) -> Bool {
        if case .drag(_) = type { return true }
        return false
    }

    private func accessorySymbol(for type: SectionType) -> String? {
        switch type {
        case .drag: return "line.3.horizontal"
        case .singleSelect, .multipleSelect: return "checkmark"
        case .normal: return nil
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
        let textColor: UIColor = switch model.style {
        case .default: .label
        case .highlight: sheetConfig.highlightColor
        case .destructive: .systemRed
        }
        return BoneDrawerSheetCell.Configuration(
            text: model.text,
            textColor: textColor,
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
            accessoryImage: accessorySymbol(for: type).flatMap { UIImage(systemName: $0) },
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
        guard presentationState != .dismissing, sections.indices.contains(indexPath.section),
              sections[indexPath.section].buttons.indices.contains(indexPath.row) else { return }
        let section = sections[indexPath.section]
        let model = section.buttons[indexPath.row]
        switch section.type {
        case .normal(_):
            if model.dismissesPopover { hidden { model.callback?() } }
            else { model.callback?() }
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
        headerHeight(forSection: section)
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0.01
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard sheetConfig.openSectionTitle, section > 0,
              !sections[section].type.title.isEmpty else { return nil }
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
        row.rowIdentifier = sections[indexPath.section].buttons[indexPath.row].accessibilityIdentifier
            ?? "drawer-row-\(indexPath.section)-\(indexPath.row)"
        row.accessibilityLabel = sections[indexPath.section].buttons[indexPath.row].text
        row.accessibilityTraits = .button
        row.isSelected = isSelectedRow(at: indexPath)
        row.accessibilityValue = isSelectedRow(at: indexPath) ? "已选中" : nil
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
