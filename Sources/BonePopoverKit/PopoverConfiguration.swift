import UIKit

/// Appearance is independent of placement and animation. All cases work on iOS 15+.
@MainActor
public struct PopoverAppearance {
    public enum Material {
        case solid
        case blur(UIBlurEffect.Style)
        /// Native UIGlassEffect on iOS 26+, system material on earlier releases.
        case liquidGlass
        /// Liquid Glass when available, otherwise the classic solid surface.
        case automatic
    }

    public var material: Material = .automatic
    public var backgroundColor: UIColor = .secondarySystemBackground
    public var tintColor: UIColor? = nil
    public var cornerRadius: CGFloat = 24
    public var borderColor: UIColor = .separator
    public var borderWidth: CGFloat = 0
    public var shadowColor: UIColor = .black
    public var shadowOpacity: Float = 0.16
    /// 应用圆角的角集合，映射 CALayer.maskedCorners；默认四角。
    /// 底部 sheet 通常只圆顶部两角，可通过该字段实现阅读器样式的非对称圆角。
    public var maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                             .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    public var shadowRadius: CGFloat = 24
    public var shadowOffset = CGSize(width: 0, height: 8)
    /// Native glass supplies its own rim and shadow. Enable only to add the
    /// custom shadow settings above on top of that system rendering.
    public var addsShadowToLiquidGlass: Bool = false
    public var backdropColor: UIColor = .black
    public var backdropOpacity: CGFloat = 0.32
    public var showsGrabber: Bool = false

    public init() {}

    public static var classic: Self {
        var value = Self()
        value.material = .solid
        value.cornerRadius = 16
        return value
    }

    public static var frosted: Self {
        var value = Self()
        value.material = .blur(.systemMaterial)
        return value
    }

    public static var liquidGlass: Self {
        var value = Self()
        value.material = .liquidGlass
        return value
    }
}

public enum PopoverPlacement: Sendable {
    case bottom, center, top, leading, trailing
}

public enum PopoverDimension: Sendable {
    case content
    case fixed(CGFloat)
    case fraction(CGFloat)
    case fill
}

public enum PopoverRegionPreference: Sendable {
    /// Prefer the trailing/bottom pane when two panes have comparable space.
    case automatic
    case largest, leading, trailing, top, bottom
}

/// Geometry is always expressed in the presenting container's coordinate space.
public struct PopoverLayout {
    public var placement: PopoverPlacement = .bottom
    public var width: PopoverDimension = .fill
    public var height: PopoverDimension = .content
    public var maximumWidth: CGFloat = 560
    public var maximumHeight: CGFloat = .greatestFiniteMagnitude
    public var margins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    public var regionPreference: PopoverRegionPreference = .automatic
    /// A source point selects the usable pane closest to the source.
    public var anchorPoint: CGPoint? = nil
    public var avoidsKeyboard: Bool = true
    public var avoidsReservedRegions: Bool = true

    public init() {}
}

@MainActor
public struct PopoverConfiguration {
    public var appearance = PopoverAppearance()
    /// 内置确认框、输入框、操作列表和 Toast 的统一字体、颜色、对齐及内部间距。
    /// 显示期间可修改；面板外部留白和最大尺寸由 layout 单独控制。
    public var contentStyle = PopoverContentStyle()
    /// 界面样式覆盖，默认 `.unspecified` 跟随宿主与系统，行为与旧版本一致。
    /// 需要固定浅色/深色的读者弹层时设为 `.light` / `.dark`。
    public var interfaceStyle: UIUserInterfaceStyle = .unspecified
    /// 内置按钮标题；nil 字段沿用 SDK 默认文案（确认框为“确认”“取消”），
    /// 宿主可在此传入已本地化的文字。显示期间修改会立即生效并重新测量。
    public var buttonTitles = PopoverButtonTitles()
    /// 独立窗口的创建选项；每次展示保存快照，页面模式不使用这些选项。
    public var window = PopoverWindowConfiguration()
    public var layout = PopoverLayout()
    public var animation = PopoverAnimation.slide(.bottom)
    /// Controls the dimming color only, independently of outside touch handling.
    public var showsBackdrop = true
    public var dismissOnBackdropTap = true
    /// Let touches outside the panel reach controls in the presenting container.
    public var allowsEventPenetration = false
    /// In penetration mode, also request dismissal after an outside tap ends.
    /// This is independent of dismissOnBackdropTap, which applies to blocked taps.
    public var autoHideWhenPenetrated = false
    public var allowsDragToDismiss = true
    /// Physical directions; .automatic follows placement (all four for center).
    public var allowedSwipeDirections: PopoverSwipeDirection = .automatic
    /// Projected travel in points needed to dismiss; release velocity contributes
    /// 0.15 seconds of travel. A slow drag must cross this distance.
    public var swipeThreshold: CGFloat = 100
    public var respectsReduceMotion = true
    public var respectsReduceTransparency = true
    /// Content larger than the available pane remains reachable by scrolling.
    public var scrollsOverflow = true

    public init() {}

    public static var bottomSheet: Self {
        var value = Self()
        // 阅读器默认样式：纯色表面、圆角 16 仅顶部两角、全宽贴底，
        // 默认无背景遮罩、无抓手、无阴影，0.15 秒从底部滑入；标题默认居中。
        value.appearance.material = .solid
        value.appearance.backgroundColor = .systemBackground
        value.appearance.cornerRadius = 16
        value.appearance.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        value.appearance.shadowOpacity = 0
        value.appearance.showsGrabber = false
        value.showsBackdrop = false
        value.contentStyle.titleAlignment = .center
        value.layout.margins = .zero
        value.animation = .slide(.bottom, duration: 0.15)
        return value
    }

    public static var centerDialog: Self {
        var value = Self()
        value.layout.placement = .center
        value.layout.maximumWidth = 420
        value.animation = .scale
        value.allowsDragToDismiss = false
        return value
    }

    public static var topBanner: Self {
        var value = Self()
        value.layout.placement = .top
        value.appearance.backdropOpacity = 0.12
        value.animation = .slide(.top)
        return value
    }

    public static var sidePanel: Self {
        var value = Self()
        value.layout.placement = .trailing
        value.layout.maximumWidth = 400
        value.layout.height = .fill
        value.animation = .slide(.trailing)
        return value
    }
}

/// 内置按钮标题。所有字段默认为 nil，表示沿用 SDK 默认文案。
public struct PopoverButtonTitles: Equatable {
    /// 确认按钮标题；nil 使用“确认”。
    public var confirm: String?
    /// 取消按钮标题；nil 使用“取消”。
    public var cancel: String?

    public init(confirm: String? = nil, cancel: String? = nil) {
        // 空字符串视为无效输入，回退默认文案。
        self.confirm = confirm.flatMap { $0.isEmpty ? nil : $0 }
        self.cancel = cancel.flatMap { $0.isEmpty ? nil : $0 }
    }
}
