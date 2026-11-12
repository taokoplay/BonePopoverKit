import UIKit

/// 抽屉式底部弹层：标题 + 抓手 + 分组行。
///
/// 用法沿用阅读器旧实现：先 `init(title:)`，再用 `addButton(text:value:style:inSection:)`
/// 逐个添加行，分区的交互方式由 `SectionType` 决定：
/// - `.normal`：点击执行回调并关闭；
/// - `.singleSelect`：分区内单选，点一次切换一次，由“确定”提交；
/// - `.multipleSelect`：分区内多选，“确定”提交全部选中项；
/// - `.drag`：行按添加顺序参与提交（当前版本不支持拖动排序）。
///
/// 提交结果通过 `selectAction { ... }` 回传 `[(text: String, value: String)]`。
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
        /// 分区之间的间距，默认 10 点。
        public var sectionHeight: CGFloat = 10
        /// 行文字字体，默认 16 点加粗。
        public var fontSize: UIFont = .boldSystemFont(ofSize: 16)
        /// 行高，默认 55 点；文字换行时会继续增高。
        public var cellHeight: CGFloat = 55
        /// `.highlight` 行的文字颜色与选中勾选颜色，默认跟随 tintColor。
        public var highlightColor: UIColor = .tintColor
        /// 行文字对齐，默认左对齐。
        public var textAlignment: NSTextAlignment = .left
        /// 行背景色，默认次级背景；面板底色由 `configuration.appearance.backgroundColor` 控制。
        public var cellBackgroundColor: UIColor = .secondarySystemBackground
        /// 分组首尾行的圆角，默认 10 点。
        public var cellCornerRadius: CGFloat = 10
        /// 行背景与面板左右边缘的间距，默认 16 点。
        public var horizontalInset: CGFloat = 16
        /// 行之间的分隔线颜色，默认系统分隔色；每个分区最后一行不画。
        public var cellSeparatorColor: UIColor = .separator

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

    /// 是否包含拖拽分区。
    public var hasDragOperation: Bool {
        sections.contains { if case .drag(_) = $0.type { return true } else { return false } }
    }

    /// 确认按钮文案；nil 使用“确定”。
    public var confirmTitle: String? {
        didSet { applyButtonTitles() }
    }

    /// 右上角关闭按钮的辅助功能标签；nil 使用“关闭”。
    public var closeAccessibilityLabel: String? {
        didSet { applyButtonTitles() }
    }

    /// 标题控件；字体、颜色与对齐由 `configuration.contentStyle` 刷新。
    public let titleLabel = UILabel()
    /// 标题行右侧按钮；默认显示“确定”并提交选中项，宿主可改文案、图标或自行接管点击。
    public var trailingButton: UIButton { confirmButton }
    /// 自定义右侧按钮点击行为：设置后不再执行默认的“提交并关闭”，由宿主自行处理。
    public var onTrailingButtonTap: (() -> Void)? {
        didSet { applyTrailingButtonVisibility() }
    }

    private struct ButtonModel {
        var text: String
        var value: String
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
    private var rowControls: [[UIControl]] = []

    private let contentStack = makePopoverStack()
    /// 仅用于复用共享排版函数；抽屉没有正文行。
    private let typographyPlaceholder = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    /// 创建抽屉；分区与行通过 `addButton(text:value:style:inSection:)` 添加。
    public init(title: String) {
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        configuration = .bottomSheet
        configuration.appearance.showsGrabber = true
        configuration.contentStyle.titleFont = .systemFont(ofSize: 14)
        configuration.contentStyle.titleAlignment = .center
        configuration.contentStyle.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0,
                                                                          bottom: 20, trailing: 0)
    }

    /// 提交回调：单选/多选返回选中项，拖拽分区按当前顺序返回全部。
    public func selectAction(_ callback: @escaping ([(text: String, value: String)]) -> Void) {
        selectCallback = callback
    }

    /// 添加一行。
    /// - Parameters:
    ///   - text: 行文字。
    ///   - value: 业务值，随提交结果回传。
    ///   - style: `.default` 或 `.highlight`。
    ///   - sectionType: 所属分区；标题相同即视为同一分区，不存在时自动创建。
    ///   - callback: `.normal` 分区点击后的业务回调；选择型分区忽略。
    public func addButton(text: String, value: String = "", style: ButtonStyle = .default,
                          inSection sectionType: SectionType = .normal(""),
                          callback: (() -> Void)? = nil) {
        let model = ButtonModel(text: text, value: value, style: style, callback: callback)
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
        configurePopoverLabel(titleLabel)
        titleLabel.accessibilityTraits.insert(.header)
        contentStack.spacing = 0
        contentStack.addArrangedSubview(makeHeaderRow())
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
        setContentView(contentStack)
        rebuildRows()
    }

    open override func applyContentStyle() {
        guard isViewLoaded else { return }
        let style = configuration.contentStyle
        applyPopoverTypography(style, title: titleLabel, message: typographyPlaceholder,
                               buttons: [confirmButton, cancelButton], traits: traitCollection)
        contentStack.directionalLayoutMargins = style.resolvedContentInsets
        rebuildRows()
    }

    // MARK: - 构建

    /// 按当前 sections 重建行与按钮；调用开销小，可直接在增删与配置变化时复用。
    private func rebuildRows() {
        guard isViewLoaded else { return }
        // 只保留首个标题行，其余（分区标题与行）全部重建，避免重复堆积。
        for view in contentStack.arrangedSubviews.dropFirst() {
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        rowControls = sections.map { _ in [] }

        for (sectionIndex, section) in sections.enumerated() {
            if sectionIndex > 0 || sheetConfig.openSectionTitle {
                contentStack.addArrangedSubview(makeSectionHeader(section, isFirst: sectionIndex == 0))
            }
            for (rowIndex, model) in section.buttons.enumerated() {
                let row = makeRow(model, indexPath: IndexPath(row: rowIndex, section: sectionIndex),
                                  type: section.type,
                                  isFirst: rowIndex == 0,
                                  isLast: rowIndex == section.buttons.count - 1)
                contentStack.addArrangedSubview(row)
                rowControls[sectionIndex].append(row)
            }
        }

        applyTrailingButtonVisibility()
        refreshSelection()
        invalidatePopoverLayout()
    }

    /// 标题行：标题居中，左侧关闭按钮（×），右侧自定义按钮（默认“确定”）。
    private func makeHeaderRow() -> UIView {
        let header = UIView()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(systemName: "xmark",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        closeConfig.baseForegroundColor = .secondaryLabel
        cancelButton.configuration = closeConfig
        cancelButton.accessibilityIdentifier = "drawer-close"
        cancelButton.accessibilityLabel = resolvedCloseLabel
        header.addSubview(cancelButton)

        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        var confirmConfig = UIButton.Configuration.tinted()
        confirmConfig.title = resolvedConfirmTitle
        confirmConfig.cornerStyle = .capsule
        confirmConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        confirmButton.configuration = confirmConfig
        confirmButton.configuration?.baseForegroundColor = sheetConfig.highlightColor
        header.addSubview(confirmButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 56),
            titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -56),
            cancelButton.topAnchor.constraint(equalTo: header.topAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 8),
            cancelButton.widthAnchor.constraint(equalToConstant: 40),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            confirmButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -12),
            confirmButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        return header
    }

    /// 右侧按钮：默认只在有选择型分区时出现；宿主自定义回调时始终显示。
    private func applyTrailingButtonVisibility() {
        guard isViewLoaded else { return }
        confirmButton.isHidden = !(hasConfirmOperation || onTrailingButtonTap != nil)
    }

    private func makeSectionHeader(_ section: Section, isFirst: Bool) -> UIView {
        let container = UIView()
        if sheetConfig.openSectionTitle {
            let label = UILabel()
            label.text = section.type.title
            label.font = .preferredFont(forTextStyle: .footnote)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: isFirst ? 10 : sheetConfig.sectionHeight),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
            ])
        } else {
            container.heightAnchor.constraint(equalToConstant: isFirst ? 8 : sheetConfig.sectionHeight).isActive = true
        }
        return container
    }

    private func makeRow(_ model: ButtonModel, indexPath: IndexPath, type: SectionType,
                         isFirst: Bool, isLast: Bool) -> UIControl {
        let row = UIControl()
        row.accessibilityIdentifier = "drawer-row-\(indexPath.section)-\(indexPath.row)"
        row.accessibilityLabel = model.text
        row.accessibilityTraits = .button
        row.backgroundColor = .clear

        // 背景层单独承担颜色与分组圆角，行本身保持透明以便露出面板底色。
        let background = UIView()
        background.backgroundColor = sheetConfig.cellBackgroundColor
        background.accessibilityIdentifier = "drawer-row-bg"
        background.layer.cornerRadius = sheetConfig.cellCornerRadius
        background.layer.maskedCorners = cornerMask(isFirst: isFirst, isLast: isLast)
        background.layer.masksToBounds = true
        background.isUserInteractionEnabled = false
        background.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(background)

        let label = UILabel()
        label.text = model.text
        label.numberOfLines = 0
        label.textAlignment = sheetConfig.textAlignment
        label.font = sheetConfig.fontSize
        label.adjustsFontForContentSizeCategory = true
        label.textColor = model.style == .highlight ? sheetConfig.highlightColor : .label

        let accessory = UIImageView(image: UIImage(systemName: accessorySymbol(for: type)))
        accessory.tintColor = sheetConfig.highlightColor
        accessory.contentMode = .scaleAspectFit
        accessory.isHidden = true
        accessory.tag = 99
        accessory.setContentHuggingPriority(.required, for: .horizontal)
        accessory.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let stack = UIStackView(arrangedSubviews: [label, accessory])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)

        let separator = UIView()
        separator.backgroundColor = sheetConfig.cellSeparatorColor
        separator.isHidden = isLast
        separator.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(separator)

        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: row.topAnchor),
            background.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            background.leadingAnchor.constraint(equalTo: row.leadingAnchor,
                                                constant: sheetConfig.horizontalInset),
            background.trailingAnchor.constraint(equalTo: row.trailingAnchor,
                                                 constant: -sheetConfig.horizontalInset),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: sheetConfig.cellHeight),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            separator.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 15),
            separator.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -15),
            separator.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        row.addAction(UIAction { [weak self] _ in
            self?.handleTap(indexPath: indexPath)
        }, for: .touchUpInside)
        return row
    }

    /// 分组首行只圆上两角、末行只圆下两角、单行四角全圆。
    private func cornerMask(isFirst: Bool, isLast: Bool) -> CACornerMask {
        if isFirst && isLast {
            return [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        if isFirst { return [.layerMinXMinYCorner, .layerMaxXMinYCorner] }
        if isLast { return [.layerMinXMaxYCorner, .layerMaxXMaxYCorner] }
        return []
    }

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

    private func handleTap(indexPath: IndexPath) {
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].buttons.count else { return }
        let model = sections[indexPath.section].buttons[indexPath.row]
        switch sections[indexPath.section].type {
        case .normal(_):
            model.callback?()
            hidden()
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

    private func refreshSelection() {
        for (sectionIndex, section) in sections.enumerated() where sectionIndex < rowControls.count {
            for (rowIndex, row) in rowControls[sectionIndex].enumerated() {
                let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                let showsCheck: Bool
                switch section.type {
                case .normal(_): showsCheck = false
                case .drag(_): showsCheck = true
                case .singleSelect(_, _), .multipleSelect(_, _): showsCheck = selectIndexPath.contains(indexPath)
                }
                row.viewWithTag(99)?.isHidden = !showsCheck
                row.accessibilityValue = showsCheck ? "已选中" : nil
            }
        }
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
        confirmButton.configuration?.title = resolvedConfirmTitle
        cancelButton.accessibilityLabel = resolvedCloseLabel
        invalidatePopoverLayout()
    }
}
