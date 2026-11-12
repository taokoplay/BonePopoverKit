import UIKit

/// 确认框和输入框中两个操作按钮的排列方式。
/// - `automatic`：根据可用宽度、完整按钮文案和样式自动选择，辅助功能字号下使用竖排。
/// - `horizontal`：固定等宽横排，取消在 leading，确认在 trailing。
/// - `vertical`：固定等宽竖排，确认在上，取消在下。
public enum PopoverAlertButtonLayout: Sendable {
    case automatic, horizontal, vertical
}

/// 内置确认框、输入框、操作列表和 Toast 共用的字体与内部间距配置。
/// 通过 `configuration.contentStyle` 设置；显示期间修改会刷新控件并重新测量弹窗尺寸。
/// 字体应传入未经缩放的基础 UIFont，启用动态字号时由 SDK 使用 UIFontMetrics 缩放。
/// 样式是值类型：赋给多个弹窗后，各弹窗保存自己的副本，可以分别调整。
@MainActor
public struct PopoverContentStyle {
    // MARK: - 字体与颜色

    /// 标题基础字体，默认 18 点系统粗体；启用动态字号后按 headline 样式缩放。
    public var titleFont: UIFont = .boldSystemFont(ofSize: 18)

    /// 正文基础字体，默认 17 点系统常规字体；启用动态字号后按 body 样式缩放。
    public var messageFont: UIFont = .systemFont(ofSize: 17)

    /// 操作按钮的基础字体，默认 17 点；确认、取消及操作列表按钮均使用此设置。
    public var buttonFont: UIFont = .systemFont(ofSize: 17)

    /// 单字段输入框的基础字体，默认 17 点，用于输入预设中的 UITextField。
    public var inputFont: UIFont = .systemFont(ofSize: 17)

    /// 标题颜色，默认系统主文字色，随浅色/深色模式适配。
    public var titleColor: UIColor = .label

    /// 正文颜色，默认系统次要文字色，随浅色/深色模式适配。
    public var messageColor: UIColor = .secondaryLabel

    // MARK: - 对齐与内容间距

    /// 标题对齐方式，默认左对齐，可按需要设为居中或右对齐。
    public var titleAlignment: NSTextAlignment = .left

    /// 正文对齐方式，默认 natural，跟随文字本身的书写方向。
    public var messageAlignment: NSTextAlignment = .natural

    /// 内容内部留白，默认四边各 24 点；leading/trailing 随界面布局方向变化。
    /// 此处不包含底部抓手区域；面板外部留白由 configuration.layout.margins 控制。
    public var contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)

    /// 标题到正文或输入框的间距，默认 14 点；Toast 用作图文间距（预设 12 点）。
    public var titleToContentSpacing: CGFloat = 14

    /// 正文或输入框到按钮区域的间距，默认 14 点。
    /// 无正文的操作列表中，表示标题到首个按钮的间距。
    public var contentToButtonsSpacing: CGFloat = 14

    /// 按钮之间的间距，默认 12 点；适用于横排、竖排和操作列表。
    public var buttonSpacing: CGFloat = 12

    /// 按钮内部文字/图标周围的留白，默认上下 12 点、leading/trailing 各 16 点。
    public var buttonContentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)

    // MARK: - 动态字号与按钮排列

    /// 是否随系统文字大小缩放字体，默认开启；关闭后使用传入的基础字号。
    /// 此开关不改变 automatic 在辅助功能字号下优先竖排按钮的策略。
    public var adjustsFontForContentSizeCategory = true

    /// Alert 的按钮排列方式，默认 automatic；操作列表始终保持竖排。
    public var buttonLayout: PopoverAlertButtonLayout = .automatic

    // MARK: - 操作列表头部

    /// 操作列表标题左侧关闭按钮的图标，默认 nil 使用 12 点 medium 的 `chevron.down`。
    /// 替换图标后仍沿用标题色；关闭按钮的辅助功能标签与点击行为不变。
    public var closeButtonImage: UIImage?

    /// 关闭按钮的方形命中区边长，默认 40 点；非有限或非正值回退 40 点。
    public var closeButtonSize: CGFloat = 40

    /// 创建使用 SDK 默认字体、颜色、对齐与间距的内容样式。
    public init() {}

    /// 每次根据当前环境从基础字体计算显示字体，避免在上一次缩放结果上重复叠加。
    func font(_ base: UIFont, textStyle: UIFont.TextStyle, traits: UITraitCollection) -> UIFont {
        adjustsFontForContentSizeCategory
            ? UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base, compatibleWith: traits) : base
    }

    // MARK: - 布局使用的有效值

    /// 清理非法间距后供布局使用，不改写调用方保存的原始配置。
    var resolvedContentInsets: NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(top: metric(contentInsets.top, fallback: 24),
                                leading: metric(contentInsets.leading, fallback: 24),
                                bottom: metric(contentInsets.bottom, fallback: 24),
                                trailing: metric(contentInsets.trailing, fallback: 24))
    }

    /// 关闭按钮的实际边长：过滤非法值后供约束使用。
    var resolvedCloseButtonSize: CGFloat {
        closeButtonSize.isFinite && closeButtonSize > 0 ? closeButtonSize : 40
    }

    /// 按钮内边距同样经过合法性处理，避免非法值进入 UIKit 布局计算。
    var resolvedButtonContentInsets: NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(top: metric(buttonContentInsets.top, fallback: 12),
                                leading: metric(buttonContentInsets.leading, fallback: 16),
                                bottom: metric(buttonContentInsets.bottom, fallback: 12),
                                trailing: metric(buttonContentInsets.trailing, fallback: 16))
    }
    var resolvedTitleSpacing: CGFloat { metric(titleToContentSpacing, fallback: 14) }
    var resolvedContentSpacing: CGFloat { metric(contentToButtonsSpacing, fallback: 14) }
    var resolvedButtonSpacing: CGFloat { metric(buttonSpacing, fallback: 12) }

    /// 负值按 0 处理；NaN 或无穷值回退到对应默认值，保证布局尺寸有效。
    private func metric(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : fallback
    }
}
