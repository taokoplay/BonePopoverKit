import UIKit

/// 无遮罩、允许操作底层页面的短时提示，支持顶部/底部长条和居中方块。
/// 沿用 BonePopoverView 的全部展示入口；自动关闭计时从展示完成后开始。
@MainActor
open class BoneToastView: BonePopoverView {
    public enum Style: Sendable {
        case top, bottom, center
    }

    /// 提示语义独立于布局；四种类型都默认在展示完成 2 秒后消失。
    public enum ToastType: CaseIterable, Sendable {
        case success, failure, info, loading
    }

    /// 显示期间切换类型会更新图标/进度圈，并按当前 duration 重新计时。
    public var type: ToastType {
        didSet {
            updateIndicator()
            invalidatePopoverLayout()
            restartDismissalTimer()
            announceIfNeeded()
        }
    }

    /// 本实例的布局样式，在初始化时确定。
    public let style: Style
    /// 字体、颜色和对齐由 configuration.contentStyle 管理。
    public let messageLabel = UILabel()
    /// 类型图标或自定义图片；加载中由 loadingIndicator 替代。
    public let imageView = UIImageView()
    /// 加载中使用的原生进度圈，随展示、关闭和类型切换自动开始或停止。
    public let loadingIndicator = UIActivityIndicatorView(style: .medium)

    /// Toast 各类型的朗读描述；字段默认 nil，使用内置中文文案。
    public struct TypeDescriptions: Equatable {
        public var success: String?
        public var failure: String?
        public var info: String?
        public var loading: String?

        public init(success: String? = nil, failure: String? = nil,
                    info: String? = nil, loading: String? = nil) {
            self.success = success
            self.failure = failure
            self.info = info
            self.loading = loading
        }
    }

    /// 类型朗读描述，用于辅助功能值与穿透模式的 announcement；修改后立即刷新。
    public var typeDescriptions = TypeDescriptions() {
        didSet {
            guard isViewLoaded else { return }
            updateIndicator()
        }
    }

    /// 提示文字；显示期间修改会自动重新测量。
    public var message: String {
        get { messageLabel.text ?? "" }
        set {
            messageLabel.text = newValue
            invalidatePopoverLayout()
        }
    }

    /// 可选自定义图标；nil 恢复当前类型的默认图标。
    /// 加载中始终显示进度圈，切回其他类型时恢复自定义图标。
    public var image: UIImage? {
        get { customImage }
        set {
            customImage = newValue
            updateIndicator()
            invalidatePopoverLayout()
        }
    }

    /// 展示完成后的停留秒数，默认 2 秒。非正值或非有限值禁用自动关闭。
    /// 显示期间修改会从修改时重新计时；自动与程序关闭均不经过 shouldDismiss。
    public var duration: TimeInterval {
        didSet { restartDismissalTimer() }
    }

    private let contentStack = UIStackView()
    private let contentScrollView = UIScrollView()
    private let indicatorContainer = UIView()
    private var customImage: UIImage?
    private var dismissalTask: Task<Void, Never>?

    public init(message: String, type: ToastType = .info, style: Style = .bottom,
                image: UIImage? = nil, duration: TimeInterval = 2) {
        self.type = type
        self.style = style
        self.duration = duration
        customImage = image
        super.init(nibName: nil, bundle: nil)
        messageLabel.text = message
        configuration = Self.toastConfiguration(for: style)
        updateIndicator()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel.numberOfLines = 0
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = false
        loadingIndicator.isAccessibilityElement = false
        loadingIndicator.style = style == .center ? .large : .medium
        indicatorContainer.isUserInteractionEnabled = false
        for child in [imageView, loadingIndicator] {
            child.translatesAutoresizingMaskIntoConstraints = false
            indicatorContainer.addSubview(child)
        }
        let iconSize: CGFloat = style == .center ? 40 : 24
        let iconWidth = indicatorContainer.widthAnchor.constraint(equalToConstant: iconSize)
        let iconHeight = indicatorContainer.heightAnchor.constraint(equalToConstant: iconSize)
        // 隐藏 arrangedSubview 时，UIStackView 会将对应轴上的尺寸压缩为零。
        iconWidth.priority = .defaultHigh
        iconHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            iconWidth, iconHeight,
            imageView.leadingAnchor.constraint(equalTo: indicatorContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: indicatorContainer.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: indicatorContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: indicatorContainer.bottomAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: indicatorContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: indicatorContainer.centerYAnchor)
        ])
        contentStack.axis = style == .center ? .vertical : .horizontal
        contentStack.alignment = .center
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.insetsLayoutMarginsFromSafeArea = false
        contentStack.setContentHuggingPriority(.required, for: .vertical)
        contentStack.addArrangedSubview(indicatorContainer)
        contentStack.addArrangedSubview(messageLabel)
        if style == .center {
            messageLabel.widthAnchor.constraint(equalTo: contentStack.layoutMarginsGuide.widthAnchor).isActive = true
        }

        // 内部滚动保留居中面板的正方形轮廓，同时让长文案/大字号仍可读完。
        contentScrollView.contentInsetAdjustmentBehavior = .never
        let container = UIView()
        for child in [contentScrollView, container, contentStack] {
            child.translatesAutoresizingMaskIntoConstraints = false
        }
        baseView.addSubview(contentScrollView)
        contentScrollView.addSubview(container)
        container.addSubview(contentStack)
        let frameGuide = contentScrollView.frameLayoutGuide
        let contentGuide = contentScrollView.contentLayoutGuide
        let fillsHeight = container.heightAnchor.constraint(equalTo: frameGuide.heightAnchor)
        fillsHeight.priority = .defaultLow
        NSLayoutConstraint.activate([
            contentScrollView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
            contentScrollView.topAnchor.constraint(equalTo: baseView.topAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor),
            container.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
            container.widthAnchor.constraint(equalTo: frameGuide.widthAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualTo: frameGuide.heightAnchor),
            fillsHeight,
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            contentStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        applyContentStyle()
    }

    open override func applyContentStyle() {
        guard isViewLoaded else { return }
        let style = configuration.contentStyle
        messageLabel.font = style.font(style.messageFont, textStyle: .body, traits: traitCollection)
        messageLabel.adjustsFontForContentSizeCategory = style.adjustsFontForContentSizeCategory
        messageLabel.textColor = style.messageColor
        messageLabel.textAlignment = style.messageAlignment
        updateIndicator()
        contentStack.directionalLayoutMargins = style.resolvedContentInsets
        contentStack.spacing = style.resolvedTitleSpacing
    }

    open override func preferredPopoverSize(fitting availableSize: CGSize) -> CGSize {
        loadViewIfNeeded()
        guard style == .center else {
            return CGSize(width: availableSize.width, height: contentHeight(fitting: availableSize.width))
        }
        let limit = max(0, min(availableSize.width, availableSize.height, configuration.layout.maximumHeight))
        var lower = min(160, limit)
        var upper = limit
        if contentHeight(fitting: lower) <= lower {
            return CGSize(width: lower, height: lower)
        }
        // 在可用范围内寻找容纳内容的最小方块；超出上限的部分由内部滚动承载。
        while upper - lower > 1 {
            let middle = (lower + upper) / 2
            if contentHeight(fitting: middle) > middle { lower = middle }
            else { upper = middle }
        }
        let side = min(limit, ceil(upper))
        return CGSize(width: side, height: side)
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateIndicator()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateIndicator()
        restartDismissalTimer()
        announceIfNeeded()
    }

    open override func viewWillDisappear(_ animated: Bool) {
        cancelDismissalTimer()
        loadingIndicator.stopAnimating()
        super.viewWillDisappear(animated)
    }

    open override func notificationHidden(type: CLPopoverDismissType) {
        cancelDismissalTimer()
        loadingIndicator.stopAnimating()
        super.notificationHidden(type: type)
    }

    /// 类型朗读描述：typeDescriptions 优先，默认沿用既有中文 key 的本地化查找。
    private var typeDescription: String {
        switch type {
        case .success: return resolved(typeDescriptions.success, key: "成功")
        case .failure: return resolved(typeDescriptions.failure, key: "失败")
        case .info: return resolved(typeDescriptions.info, key: "提示")
        case .loading: return resolved(typeDescriptions.loading, key: "加载中")
        }
    }

    /// nil 或空字符串都回退默认文案。
    private func resolved(_ text: String?, key: String) -> String {
        guard let text, !text.isEmpty else { return NSLocalizedString(key, comment: "Toast type") }
        return text
    }

    private func updateIndicator() {
        let symbolName: String? = switch type {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .info: "info.circle.fill"
        case .loading: nil
        }
        let color: UIColor = switch type {
        case .success: .systemGreen
        case .failure: .systemRed
        case .info: .systemBlue
        case .loading: configuration.contentStyle.messageColor
        }
        imageView.image = customImage ?? symbolName.flatMap { UIImage(systemName: $0) }
        imageView.tintColor = customImage == nil ? color : configuration.contentStyle.messageColor
        imageView.isHidden = type == .loading
        indicatorContainer.isHidden = type != .loading && imageView.image == nil
        loadingIndicator.color = configuration.contentStyle.messageColor
        loadingIndicator.isHidden = type != .loading
        if type == .loading, presentationState == .presenting || presentationState == .presented {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
        messageLabel.accessibilityValue = typeDescription
    }

    private func announceIfNeeded() {
        if presentationState == .presented, configuration.allowsEventPenetration {
            UIAccessibility.post(notification: .announcement, argument: "\(typeDescription)，\(message)")
        }
    }

    private func contentHeight(fitting width: CGFloat) -> CGFloat {
        contentStack.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel).height
    }

    private func restartDismissalTimer() {
        cancelDismissalTimer()
        guard presentationState == .presented, duration.isFinite, duration > 0,
              let identifier = presentationIdentifier else { return }
        let seconds = min(duration, TimeInterval(UInt64.max / 1_000_000_000))
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        dismissalTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: nanoseconds) }
            catch { return }
            guard !Task.isCancelled, let self, self.presentationIdentifier == identifier,
                  self.presentationState == .presented else { return }
            self.dismissPopover()
        }
    }

    private func cancelDismissalTimer() {
        dismissalTask?.cancel()
        dismissalTask = nil
    }

    private static func toastConfiguration(for style: Style) -> PopoverConfiguration {
        var value = PopoverConfiguration()
        value.appearance = .frosted
        value.appearance.cornerRadius = style == .center ? 20 : 16
        value.showsBackdrop = false
        value.dismissOnBackdropTap = false
        value.allowsEventPenetration = true
        value.autoHideWhenPenetrated = false
        value.scrollsOverflow = false
        value.window.keyPolicy = .preserveCurrent
        value.contentStyle.messageFont = .systemFont(ofSize: 16, weight: .medium)
        value.contentStyle.messageColor = .label
        value.contentStyle.messageAlignment = style == .center ? .center : .natural
        value.contentStyle.contentInsets = style == .center
            ? NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
            : NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        value.contentStyle.titleToContentSpacing = 12
        switch style {
        case .top:
            value.layout.placement = .top
            value.animation = .slide(.top, duration: 0.25)
        case .bottom:
            value.layout.placement = .bottom
            value.animation = .slide(.bottom, duration: 0.25)
        case .center:
            value.layout.placement = .center
            value.layout.width = .content
            value.layout.maximumWidth = 280
            value.layout.maximumHeight = 280
            value.animation = .scale
            value.allowsDragToDismiss = false
        }
        return value
    }
}
