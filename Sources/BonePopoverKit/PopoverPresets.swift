import UIKit

/// 确认框和单字段输入框预设，保留旧版初始化方法的参数标签。
/// 字体、颜色、对齐和内部间距统一通过 configuration.contentStyle 调整。
@MainActor
open class BoneAlertView: BonePopoverView {
    public enum AlertMode { case confirm, input }
    /// 保留原有按钮排列类型名称，与统一样式中的枚举为同一类型。
    public typealias ButtonLayout = PopoverAlertButtonLayout
    /// 当前预设类型，由使用的初始化方法决定。
    public let alertMode: AlertMode
    /// 标题控件；字体、颜色和对齐由 contentStyle 统一刷新。
    public let titleLabel = UILabel()
    /// 确认预设的正文控件；字体、颜色和对齐由 contentStyle 统一刷新。
    public let messageLabel = UILabel()
    /// 输入预设的文本控件，可直接设置密码、自动填充等 UIKit 属性。
    public let textField = UITextField()
    /// 确认按钮；关闭并移除弹窗后才执行业务回调。
    public let confirmButton = UIButton(type: .system)
    /// 取消按钮；关闭弹窗，不执行确认回调。
    public let cancelButton = UIButton(type: .system)
    /// 标题对齐的便利入口，直接读写 configuration.contentStyle.titleAlignment。
    public var titleAlignment: NSTextAlignment {
        get { configuration.contentStyle.titleAlignment }
        set { configuration.contentStyle.titleAlignment = newValue }
    }
    /// 按钮排列的便利入口，直接读写 configuration.contentStyle.buttonLayout。
    public var buttonLayout: ButtonLayout {
        get { configuration.contentStyle.buttonLayout }
        set { configuration.contentStyle.buttonLayout = newValue }
    }
    /// 面板左右最小外部留白，默认各 32 点，从已避让安全区/保留区域的可用边缘计算。
    /// 同时写入 layout.margins.left/right；读取时返回左侧值。
    /// 整份替换 configuration 会覆盖这些留白设置。
    public var horizontalMargin: CGFloat {
        get { configuration.layout.margins.left }
        set {
            guard newValue.isFinite else { return }
            var updated = configuration
            updated.layout.margins.left = max(0, newValue)
            updated.layout.margins.right = max(0, newValue)
            configuration = updated
        }
    }

    /// 整个面板的最大尺寸，默认 420 × 600 点，在 iPad 等大屏上同样生效。
    /// 实际可用空间更小时，面板会继续缩小。
    public var maximumSize: CGSize {
        get { CGSize(width: configuration.layout.maximumWidth, height: configuration.layout.maximumHeight) }
        set {
            guard newValue.width.isFinite, newValue.height.isFinite else { return }
            var updated = configuration
            updated.layout.maximumWidth = max(0, newValue.width)
            updated.layout.maximumHeight = max(0, newValue.height)
            configuration = updated
        }
    }
    /// 输入框的键盘类型，可在视图加载前设置，默认使用系统普通键盘。
    public var keyboardType: UIKeyboardType = .default {
        didSet { textField.keyboardType = keyboardType }
    }
    /// 读取或设置输入框当前文本，可在展示前填入初始值。
    public var text: String {
        get { textField.text ?? "" }
        set { textField.text = newValue }
    }
    private var confirmCallback: (() -> Void)?
    private var inputCallback: ((String) -> Void)?
    private let buttonRow = UIStackView()
    private let contentStack = makePopoverStack()

    private static var alertConfiguration: PopoverConfiguration {
        var value = PopoverConfiguration.centerDialog
        value.layout.margins.left = 32
        value.layout.margins.right = 32
        value.layout.maximumHeight = 600
        return value
    }

    /// 创建确认框，callback 在确认关闭并移除后执行。
    public init(title: String, message: String, callback: @escaping () -> Void) {
        alertMode = .confirm
        confirmCallback = callback
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        messageLabel.text = message
        configuration = BoneAlertView.alertConfiguration
    }

    /// 创建单字段输入框；默认禁止点击外部关闭，确认回调接收关闭前的文本。
    public init(title: String, placeholder: String, callback: @escaping (String) -> Void) {
        alertMode = .input
        inputCallback = callback
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        textField.placeholder = placeholder
        configuration = BoneAlertView.alertConfiguration
        configuration.dismissOnBackdropTap = false
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        configurePopoverLabel(titleLabel)
        titleLabel.accessibilityTraits.insert(.header)
        contentStack.addArrangedSubview(titleLabel)
        if alertMode == .confirm {
            configurePopoverLabel(messageLabel)
            contentStack.addArrangedSubview(messageLabel)
        } else {
            textField.borderStyle = .roundedRect
            textField.keyboardType = keyboardType
            textField.accessibilityLabel = titleLabel.text
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            contentStack.addArrangedSubview(textField)
        }
        configurePopoverButton(confirmButton, title: "确认", prominent: true)
        configurePopoverButton(cancelButton, title: "取消", prominent: false)
        confirmButton.addAction(UIAction { [weak self] _ in self?.confirm() }, for: .touchUpInside)
        cancelButton.addAction(UIAction { [weak self] _ in self?.hidden() }, for: .touchUpInside)
        buttonRow.axis = .horizontal
        buttonRow.alignment = .fill
        buttonRow.distribution = .fillEqually
        buttonRow.setContentHuggingPriority(.required, for: .vertical)
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(confirmButton)
        contentStack.addArrangedSubview(buttonRow)
        setContentView(contentStack)
        applyContentStyle()
    }

    /// 在现有控件上应用统一样式，保留输入内容、焦点及自定义按钮文案和图标。
    open override func applyContentStyle() {
        guard isViewLoaded else { return }
        let style = configuration.contentStyle
        applyPopoverTypography(style, title: titleLabel, message: messageLabel,
                               buttons: [cancelButton, confirmButton], traits: traitCollection)
        textField.font = style.font(style.inputFont, textStyle: .body, traits: traitCollection)
        textField.adjustsFontForContentSizeCategory = style.adjustsFontForContentSizeCategory
        contentStack.directionalLayoutMargins = style.resolvedContentInsets
        contentStack.spacing = style.resolvedContentSpacing
        if contentStack.arrangedSubviews.contains(titleLabel) {
            contentStack.setCustomSpacing(style.resolvedTitleSpacing, after: titleLabel)
            let content: UIView = alertMode == .confirm ? messageLabel : textField
            contentStack.setCustomSpacing(style.resolvedContentSpacing, after: content)
        }
        buttonRow.spacing = style.resolvedButtonSpacing
        baseView.setNeedsLayout()
    }

    open override func preferredPopoverSize(fitting availableSize: CGSize) -> CGSize {
        loadViewIfNeeded()
        // 先按当前字体和内部留白确定按钮排列，再测量高度，
        // 确保显示期间修改样式后，按钮方向和面板尺寸同步更新。
        let usesColumn: Bool
        switch buttonLayout {
        case .horizontal: usesColumn = false
        case .vertical: usesColumn = true
        case .automatic:
            let insets = configuration.contentStyle.resolvedContentInsets
            let buttonWidth = max(0, (availableSize.width - insets.leading - insets.trailing - buttonRow.spacing) / 2)
            // 多行按钮的固有宽度会受当前换行结果影响。
            // 这里测量不受宽度约束的完整文字/图标宽度，用于判断横排是否放得下。
            let unconstrained = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            let idealWidth = max(44, cancelButton.sizeThatFits(unconstrained).width,
                                 confirmButton.sizeThatFits(unconstrained).width)
            usesColumn = traitCollection.preferredContentSizeCategory.isAccessibilityCategory || buttonWidth < idealWidth
        }
        let axis: NSLayoutConstraint.Axis = usesColumn ? .vertical : .horizontal
        // 横排时取消位于 leading；竖排时确认在上、取消在下。
        let firstButton = usesColumn ? confirmButton : cancelButton
        if buttonRow.axis != axis || buttonRow.arrangedSubviews.first !== firstButton {
            buttonRow.arrangedSubviews.forEach { buttonRow.removeArrangedSubview($0) }
            let buttons = usesColumn ? [confirmButton, cancelButton] : [cancelButton, confirmButton]
            buttons.forEach { buttonRow.addArrangedSubview($0) }
            buttonRow.axis = axis
        }
        return super.preferredPopoverSize(fitting: availableSize)
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if alertMode == .input { textField.becomeFirstResponder() }
    }

    private func confirm() {
        guard presentationState != .dismissing else { return }
        // 先保存文本快照，关闭完成后再把确认结果交给业务，便于回调中展示下一个弹窗。
        let value = text
        let confirm = confirmCallback
        let input = inputCallback
        hidden {
            confirm?()
            input?(value)
        }
    }
}

/// 操作列表中的单个动作，包含标题、图标、视觉角色和执行方式。
@MainActor
public struct PopoverAction {
    public enum Role { case normal, destructive }
    public var title: String
    public var image: UIImage?
    /// 动作的视觉角色；destructive 使用红色强调，实际业务由 handler 处理。
    public var role: Role
    /// 默认先关闭弹窗再执行 handler；设为 false 时立即执行并保留弹窗。
    public var dismissesPopover: Bool
    public var handler: () -> Void

    public init(_ title: String, image: UIImage? = nil, role: Role = .normal,
                dismissesPopover: Bool = true, handler: @escaping () -> Void = {}) {
        self.title = title
        self.image = image
        self.role = role
        self.dismissesPopover = dismissesPopover
        self.handler = handler
    }
}

/// 紧凑的竖向操作列表，长列表默认在当前可用区域内滚动。
@MainActor
open class BoneActionSheetView: BonePopoverView {
    /// 标题控件，文字样式由 configuration.contentStyle 统一管理。
    public let titleLabel = UILabel()
    /// 可选正文控件；加载视图时正文非空才加入内容布局。
    public let messageLabel = UILabel()
    /// 按动作顺序创建的按钮，需加载视图后访问；可用于定制标题、图标或辅助功能属性。
    public private(set) var actionButtons: [UIButton] = []
    /// 列表末尾的取消按钮，点击后直接关闭弹窗。
    public let cancelButton = UIButton(type: .system)
    /// 标题对齐的便利入口，直接读写 configuration.contentStyle.titleAlignment。
    public var titleAlignment: NSTextAlignment {
        get { configuration.contentStyle.titleAlignment }
        set { configuration.contentStyle.titleAlignment = newValue }
    }
    private let actions: [PopoverAction]
    private let cancelTitle: String
    private let contentStack = makePopoverStack()

    public init(title: String, message: String? = nil, actions: [PopoverAction], cancelTitle: String = "取消") {
        self.actions = actions
        self.cancelTitle = cancelTitle
        super.init(nibName: nil, bundle: nil)
        titleLabel.text = title
        messageLabel.text = message
        configuration = .bottomSheet
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
        for action in actions {
            let button = UIButton(type: .system)
            configurePopoverButton(button, title: action.title, prominent: false)
            button.configuration?.image = action.image
            button.configuration?.imagePadding = 10
            if action.role == .destructive { button.tintColor = .systemRed }
            button.addAction(UIAction { [weak self] _ in
                guard let self, self.presentationState != .dismissing else { return }
                if action.dismissesPopover { self.hidden(action.handler) }
                else { action.handler() }
            }, for: .touchUpInside)
            actionButtons.append(button)
            contentStack.addArrangedSubview(button)
        }
        configurePopoverButton(cancelButton, title: cancelTitle, prominent: false)
        cancelButton.addAction(UIAction { [weak self] _ in self?.hidden() }, for: .touchUpInside)
        contentStack.addArrangedSubview(cancelButton)
        setContentView(contentStack)
        applyContentStyle()
    }

    /// 更新文字样式与段落/按钮间距，操作列表始终保留竖排布局。
    open override func applyContentStyle() {
        guard isViewLoaded else { return }
        let style = configuration.contentStyle
        applyPopoverTypography(style, title: titleLabel, message: messageLabel,
                               buttons: actionButtons + [cancelButton], traits: traitCollection)
        contentStack.directionalLayoutMargins = style.resolvedContentInsets
        contentStack.spacing = style.resolvedButtonSpacing
        if contentStack.arrangedSubviews.contains(titleLabel) {
            // 有正文时分别设置两段间距；无正文时使用“内容到按钮”间距连接标题和首个动作。
            let hasMessage = contentStack.arrangedSubviews.contains(messageLabel)
            contentStack.setCustomSpacing(hasMessage ? style.resolvedTitleSpacing : style.resolvedContentSpacing,
                                          after: titleLabel)
            if hasMessage { contentStack.setCustomSpacing(style.resolvedContentSpacing, after: messageLabel) }
        }
        baseView.setNeedsLayout()
    }
}

@MainActor
private func makePopoverStack() -> UIStackView {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.alignment = .fill
    // 宿主已负责安全区和系统保留区域避让，内容栈不再重复叠加这些边距。
    stack.insetsLayoutMarginsFromSafeArea = false
    stack.preservesSuperviewLayoutMargins = false
    stack.isLayoutMarginsRelativeArrangement = true
    return stack
}

@MainActor
private func configurePopoverLabel(_ label: UILabel) {
    label.numberOfLines = 0
    label.setContentCompressionResistancePriority(.required, for: .vertical)
}

@MainActor
private func configurePopoverButton(_ button: UIButton, title: String, prominent: Bool) {
    var configuration = prominent ? UIButton.Configuration.filled() : .tinted()
    configuration.title = title
    configuration.cornerStyle = .medium
    button.configuration = configuration
    button.titleLabel?.numberOfLines = 0
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
}

/// 共用的文字样式应用逻辑：只更新样式字段，保留按钮已有标题、图标和视觉角色。
@MainActor
private func applyPopoverTypography(_ style: PopoverContentStyle, title: UILabel, message: UILabel,
                                    buttons: [UIButton], traits: UITraitCollection) {
    title.font = style.font(style.titleFont, textStyle: .headline, traits: traits)
    title.adjustsFontForContentSizeCategory = style.adjustsFontForContentSizeCategory
    title.textColor = style.titleColor
    title.textAlignment = style.titleAlignment
    message.font = style.font(style.messageFont, textStyle: .body, traits: traits)
    message.adjustsFontForContentSizeCategory = style.adjustsFontForContentSizeCategory
    message.textColor = style.messageColor
    message.textAlignment = style.messageAlignment
    let font = style.font(style.buttonFont, textStyle: .body, traits: traits)
    for button in buttons {
        if var configuration = button.configuration {
            configuration.contentInsets = style.resolvedButtonContentInsets
            // 配置式按钮通过属性转换器指定字体，避免 UIKit 刷新配置后恢复系统默认字体。
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var result = attributes
                result.font = font
                return result
            }
            button.configuration = configuration
        }
        button.titleLabel?.font = font
        button.titleLabel?.adjustsFontForContentSizeCategory = style.adjustsFontForContentSizeCategory
        // UIButton.Configuration 会延迟到布局阶段更新富文本标题。
        // 在宿主测量宽高前完成更新，避免字体已修改但仍按旧配置的尺寸计算。
        button.setNeedsUpdateConfiguration()
        button.setNeedsLayout()
        button.layoutIfNeeded()
        button.invalidateIntrinsicContentSize()
    }
}
