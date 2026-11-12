import UIKit

/// 抽屉里的一行：白底 + 分组圆角 + 行首图标 + 右侧勾选/拖动图标 + 分隔线。
///
/// 布局沿用阅读器 `BoneDrawerSheetCell`：cell 自身透明，`baseView` 承担底色与圆角，
/// `lineView` 只在非末行出现，勾选图标由 `isSelected` 直接控制显隐。
@MainActor
final class BoneDrawerSheetCell: UITableViewCell {
    /// 分组内的行位置决定圆角方向。
    enum RoundStyle {
        case top
        case bottom
        case none
        case all
    }

    var roundStyle: RoundStyle = .none {
        didSet { setNeedsLayout() }
    }

    /// 右侧勾选 / 拖动图标；`isSelected` 之外的选择型分区也用它。
    let accessoryImageView = UIImageView()
    /// 行首图标底板（无图标时隐藏）。
    let iconBox = UIView()
    private let iconView = UIImageView()

    private let baseView: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.accessibilityIdentifier = "drawer-row-bg"
        return view
    }()

    private let lineView = UIView()

    /// 文字标签；内部实际使用 `titleLabel`。
    private let textLabelView = UILabel()

    /// cell 的行标识，方便 UI 测试与排查定位。
    var rowIdentifier: String? {
        get { accessibilityIdentifier }
        set { accessibilityIdentifier = newValue }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(baseView)
        contentView.addSubview(lineView)
        contentView.addSubview(iconBox)
        contentView.addSubview(textLabelView)
        contentView.addSubview(accessoryImageView)
        iconBox.addSubview(iconView)

        iconBox.isUserInteractionEnabled = false
        iconBox.accessibilityIdentifier = "drawer-row-icon"
        iconBox.layer.cornerCurve = .continuous
        iconView.contentMode = .scaleAspectFit
        iconView.isAccessibilityElement = false

        textLabelView.numberOfLines = 0
        textLabelView.setContentCompressionResistancePriority(.required, for: .vertical)

        accessoryImageView.contentMode = .scaleAspectFit
        accessoryImageView.setContentHuggingPriority(.required, for: .horizontal)
        accessoryImageView.tag = 99
        accessoryImageView.isHidden = true

        // 全部用 frame 排版（与阅读器 `pin` 一致）：不参与 Auto Layout，避免被重置成零。
    }

    required init?(coder: NSCoder) { fatalError("Use init(style:reuseIdentifier:)") }

    override var isSelected: Bool {
        didSet { accessoryImageView.isHidden = !isSelected }
    }

    /// 一行所需的全部外观；由抽屉在 `cellForRowAt` 里填。
    struct Configuration {
        var text: String
        var textColor: UIColor
        var font: UIFont
        var textAlignment: NSTextAlignment
        var cellBackgroundColor: UIColor
        var separatorColor: UIColor
        var cornerRadius: CGFloat
        var showsSeparator: Bool
        var horizontalInset: CGFloat
        var icon: UIImage?
        var iconBoxColor: UIColor?
        var iconTint: UIColor
        var iconSize: CGFloat
        var iconCornerRadius: CGFloat
        var iconSpacing: CGFloat
        var accessoryImage: UIImage?
        var accessoryTint: UIColor
    }

    func apply(_ configuration: Configuration) {
        textLabelView.text = configuration.text
        textLabelView.textColor = configuration.textColor
        textLabelView.font = configuration.font
        textLabelView.textAlignment = configuration.textAlignment
        baseView.backgroundColor = configuration.cellBackgroundColor
        baseView.layer.cornerRadius = configuration.cornerRadius
        lineView.backgroundColor = configuration.separatorColor
        lineView.isHidden = !configuration.showsSeparator
        accessoryImageView.image = configuration.accessoryImage
        accessoryImageView.tintColor = configuration.accessoryTint
        iconBox.backgroundColor = configuration.iconBoxColor
        iconBox.layer.cornerRadius = configuration.iconCornerRadius
        iconBox.isHidden = configuration.icon == nil
        if let icon = configuration.icon {
            iconView.image = icon.renderingMode == .alwaysOriginal
                ? icon : icon.withRenderingMode(.alwaysTemplate)
            iconView.tintColor = configuration.iconBoxColor == nil
                ? configuration.iconTint : configuration.iconTint
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = sheetInsets.horizontalInset
        baseView.frame = CGRect(x: inset, y: 0,
                                width: max(0, contentView.bounds.width - inset * 2),
                                height: contentView.bounds.height)
        switch roundStyle {
        case .top:
            baseView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        case .bottom:
            baseView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .all:
            baseView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                            .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        case .none:
            baseView.layer.maskedCorners = []
        }

        var textLeft = baseView.frame.minX + 16
        let iconSide = sheetInsets.iconSize
        if !iconBox.isHidden {
            iconBox.frame = CGRect(x: baseView.frame.minX + 16,
                                   y: baseView.frame.midY - iconSide / 2,
                                   width: iconSide, height: iconSide)
            let glyph = max(12, iconSide * 0.58)
            iconView.frame = CGRect(x: (iconSide - glyph) / 2, y: (iconSide - glyph) / 2,
                                    width: glyph, height: glyph)
            textLeft = iconBox.frame.maxX + sheetInsets.iconSpacing
        }

        let accessoryWidth: CGFloat = accessoryImageView.image == nil ? 0 : 20
        accessoryImageView.frame = CGRect(x: baseView.frame.maxX - 16 - accessoryWidth,
                                          y: baseView.frame.midY - 10,
                                          width: accessoryWidth, height: 20)

        let textRight = baseView.frame.maxX - 16 - (accessoryWidth > 0 ? accessoryWidth + 12 : 0)
        let textWidth = max(0, textRight - textLeft)
        let textHeight = ceil(textLabelView.sizeThatFits(CGSize(width: textWidth,
                                                               height: .greatestFiniteMagnitude)).height)
        textLabelView.frame = CGRect(x: textLeft, y: baseView.frame.midY - textHeight / 2,
                                     width: textWidth, height: textHeight)

        // 有图标的行，分隔线从文字起始处缩进（系统设置的分组列表就是这样）。
        let lineLeft = iconBox.isHidden ? baseView.frame.minX + 15 : textLeft
        lineView.frame = CGRect(x: lineLeft,
                                y: baseView.frame.maxY - 0.5,
                                width: max(0, baseView.frame.maxX - 15 - lineLeft), height: 0.5)
    }

    /// 由抽屉在每次配置时写入的布局常量（cell 复用，不能存每行独立状态之外的几何）。
    var sheetInsets = (horizontalInset: CGFloat(16), iconSize: CGFloat(32), iconSpacing: CGFloat(12))
}
