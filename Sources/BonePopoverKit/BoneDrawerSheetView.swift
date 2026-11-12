import UIKit

/// 抽屉式底部弹层：标题 + 抓手 + 分组行，支持单选、多选和不选择。
/// 与 `.bottomSheet` 共用阅读器默认表面（仅圆顶部两角、无阴影、0.15 秒滑入），
/// 默认带抓手，内容超过可用高度时由现有滚动容器承载。
@MainActor
open class BoneDrawerSheetView: BonePopoverView {
    /// 行的选择方式。
    public enum Selection: Equatable {
        /// 单选：点击即选中并关闭。
        case single
        /// 多选：点击切换勾选，保持展示，由确认按钮提交。
        case multiple
        /// 不记录选中，只把点击交给回调。
        case none
    }

    /// 一行选项。
    public struct Item: Equatable {
        public var title: String
        public var detail: String?
        public var image: UIImage?
        /// destructive 行使用红色文字，仅视觉语义，不自动二次确认。
        public var isDestructive: Bool

        public init(_ title: String, detail: String? = nil, image: UIImage? = nil,
                    isDestructive: Bool = false) {
            self.title = title
            self.detail = detail
            self.image = image
            self.isDestructive = isDestructive
        }
    }

    /// 一组选项，可选的小标题显示在组上方。
    public struct Section {
        public var title: String?
        public var items: [Item]

        public init(title: String? = nil, items: [Item]) {
            self.title = title
            self.items = items
        }
    }

    /// 标题控件；字号、颜色与对齐由 `configuration.contentStyle` 刷新。
    public let titleLabel = UILabel()
    /// 可选正文控件；文本非空时才参与布局。
    public let messageLabel = UILabel()

    /// 点击某一行时回调；多选模式下在切换勾选后回调。
    public var onSelect: ((Item) -> Void)?
    /// 多选模式点击确认按钮时回调选中项；未设置时仅关闭。
    public var onConfirm: (([Item]) -> Void)?
    /// 单选/不选择模式下，点击行是否立即关闭，默认关闭。
    public var dismissesOnSelect = true

    /// 当前选中的项（单选最多一个），按添加顺序返回。
    public var selectedItems: [Item] {
        flatItems.enumerated().filter { selectedIndices.contains($0.offset) }.map(\.element)
    }

    /// 取消按钮标题；nil 回退初始化参数，再回退“取消”。
    public var cancelTitle: String? {
        didSet { applyCancelTitle() }
    }
    /// 确认按钮标题，仅多选模式显示；nil 使用“完成”。
    public var confirmTitle: String? {
        didSet { applyConfirmTitle() }
    }

    private let sections: [Section]
    private let selection: Selection
    private let defaultCancelTitle: String
    private let showsCancel: Bool
    private let contentStack = makePopoverStack()
    private var flatItems: [Item] = []
    private var rowControls: [UIControl] = []
    private var selectedIndices: Set<Int> = []
    private let confirmButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    /// 创建抽屉式列表；默认单选、带取消按钮、无确认按钮。
    public init(title: String, message: String? = nil, sections: [Section],
                selection: Selection = .single, cancelTitle: String = "取消",
                showsCancel: Bool = true) {
        self.sections = sections
        self.selection = selection
        self.defaultCancelTitle = cancelTitle
        self.showsCancel = showsCancel
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        messageLabel.text = message
        configuration = .bottomSheet
        configuration.appearance.showsGrabber = true
        configuration.contentStyle.titleAlignment = .center
        configuration.contentStyle.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0,
                                                                          bottom: 24, trailing: 0)
    }

    /// 由外部指定初始选中项；索引按扁平顺序（跨分组连续编号）。
    public func setSelected(indices: Set<Int>) {
        selectedIndices = indices
        refreshSelection()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        configurePopoverLabel(titleLabel)
        titleLabel.accessibilityTraits.insert(.header)
        contentStack.addArrangedSubview(titleLabel)
        if let text = messageLabel.text, !text.isEmpty {
            configurePopoverLabel(messageLabel)
            contentStack.addArrangedSubview(messageLabel)
        }
        for (sectionIndex, section) in sections.enumerated() {
            if let title = section.title, !title.isEmpty {
                contentStack.addArrangedSubview(makeSectionHeader(title, isFirst: sectionIndex == 0))
            }
            for item in section.items {
                contentStack.addArrangedSubview(makeRow(item))
                flatItems.append(item)
            }
        }
        if selection == .multiple {
            configurePopoverButton(confirmButton, title: resolvedConfirmTitle, prominent: true)
            confirmButton.accessibilityIdentifier = "drawer-confirm"
            confirmButton.addAction(UIAction { [weak self] _ in self?.confirm() }, for: .touchUpInside)
            contentStack.addArrangedSubview(confirmButton)
        }
        if showsCancel {
            configurePopoverButton(cancelButton, title: resolvedCancelTitle, prominent: false)
            cancelButton.accessibilityIdentifier = "drawer-cancel"
            cancelButton.addAction(UIAction { [weak self] _ in self?.hidden() }, for: .touchUpInside)
            contentStack.addArrangedSubview(cancelButton)
        }
        setContentView(contentStack)
        applyContentStyle()
        refreshSelection()
    }

    open override func applyContentStyle() {
        guard isViewLoaded else { return }
        let style = configuration.contentStyle
        applyPopoverTypography(style, title: titleLabel, message: messageLabel,
                               buttons: [confirmButton, cancelButton], traits: traitCollection)
        contentStack.directionalLayoutMargins = style.resolvedContentInsets
        contentStack.spacing = 0
        for row in rowControls {
            applyRowStyle(row, style: style)
        }
        baseView.setNeedsLayout()
    }

    // MARK: - 行构建

    private func makeSectionHeader(_ title: String, isFirst: Bool) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        let container = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: isFirst ? 12 : 18),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])
        return container
    }

    private func makeRow(_ item: Item) -> UIControl {
        let row = UIControl()
        row.accessibilityIdentifier = "drawer-row-\(rowControls.count)"
        row.accessibilityLabel = item.title
        row.accessibilityTraits = .button

        let title = UILabel()
        title.text = item.title
        title.numberOfLines = 0
        title.textColor = item.isDestructive ? .systemRed : .label
        let detail = UILabel()
        detail.text = item.detail
        detail.numberOfLines = 0
        detail.textColor = .secondaryLabel
        detail.isHidden = item.detail == nil

        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 2

        let icon = UIImageView(image: item.image)
        icon.tintColor = item.isDestructive ? .systemRed : .label
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.isHidden = item.image == nil

        let check = UIImageView(image: UIImage(systemName: "checkmark"))
        check.tintColor = .tintColor
        check.isHidden = true
        check.tag = 99
        check.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [icon, text, check])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20)
        ])

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
            separator.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        row.addAction(UIAction { [weak self] _ in self?.handleTap(on: row) }, for: .touchUpInside)
        rowControls.append(row)
        return row
    }

    /// 行内只同步字体与动态字号，颜色由行自身的 destructive 语义决定。
    private func applyRowStyle(_ row: UIControl, style: PopoverContentStyle) {
        guard
            let stack = row.subviews.compactMap({ $0 as? UIStackView }).first,
            let text = stack.arrangedSubviews.compactMap({ $0 as? UIStackView }).first
        else { return }
        let labels = text.arrangedSubviews.compactMap { $0 as? UILabel }
        labels.first?.font = style.font(style.buttonFont, textStyle: .body, traits: traitCollection)
        labels.first?.adjustsFontForContentSizeCategory = style.adjustsFontForContentSizeCategory
        labels.last?.font = style.font(style.messageFont, textStyle: .footnote, traits: traitCollection)
        labels.last?.adjustsFontForContentSizeCategory = style.adjustsFontForContentSizeCategory
    }

    private func handleTap(on row: UIControl) {
        guard let index = rowControls.firstIndex(of: row), index < flatItems.count else { return }
        let item = flatItems[index]
        switch selection {
        case .single:
            selectedIndices = [index]
            refreshSelection()
            onSelect?(item)
            if dismissesOnSelect { hidden() }
        case .multiple:
            if selectedIndices.contains(index) { selectedIndices.remove(index) } else { selectedIndices.insert(index) }
            refreshSelection()
            onSelect?(item)
        case .none:
            onSelect?(item)
            if dismissesOnSelect { hidden() }
        }
    }

    private func refreshSelection() {
        guard isViewLoaded else { return }
        for (offset, row) in rowControls.enumerated() {
            let checked = selectedIndices.contains(offset)
            row.viewWithTag(99)?.isHidden = !checked
            row.accessibilityValue = checked ? "已选中" : nil
        }
    }

    private func confirm() {
        let selected = selectedItems
        hidden { [weak self] in
            self?.onConfirm?(selected)
        }
    }

    private var resolvedCancelTitle: String {
        if let text = cancelTitle, !text.isEmpty { return text }
        return defaultCancelTitle.isEmpty ? "取消" : defaultCancelTitle
    }

    private var resolvedConfirmTitle: String {
        if let text = confirmTitle, !text.isEmpty { return text }
        return "完成"
    }

    private func applyCancelTitle() {
        guard isViewLoaded, showsCancel, cancelButton.configuration?.title != resolvedCancelTitle else { return }
        cancelButton.configuration?.title = resolvedCancelTitle
        invalidatePopoverLayout()
    }

    private func applyConfirmTitle() {
        guard isViewLoaded, selection == .multiple,
              confirmButton.configuration?.title != resolvedConfirmTitle else { return }
        confirmButton.configuration?.title = resolvedConfirmTitle
        invalidatePopoverLayout()
    }
}
