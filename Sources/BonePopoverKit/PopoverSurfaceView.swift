import UIKit

/// The effect owns its silhouette. Only foreground content is clipped, so native
/// glass highlights and shadows can extend beyond the surface without being cut off.
@MainActor
final class PopoverSurfaceView: UIView {
    let contentContainer = UIView()
    let grabber = UIView()
    /// 背景延伸到屏幕底边时，内容仍在底部安全区上沿结束。
    var bottomContentInset: CGFloat = 0 {
        didSet {
            if bottomContentInset != oldValue { setNeedsLayout() }
        }
    }
    private let effectView = UIVisualEffectView()
    private let foregroundView = UIView()
    private var customBackgroundView: UIView?
    private var radius: CGFloat = 24
    private var cornerMask: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                           .layerMinXMaxYCorner, .layerMaxXMaxYCorner]

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(effectView)
        effectView.layer.cornerCurve = .continuous
        addSubview(foregroundView)
        foregroundView.clipsToBounds = true
        foregroundView.layer.cornerCurve = .continuous
        foregroundView.addSubview(contentContainer)
        foregroundView.addSubview(grabber)
        grabber.backgroundColor = .tertiaryLabel
        grabber.layer.cornerRadius = 2.5
        grabber.isUserInteractionEnabled = false
        grabber.isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func apply(_ appearance: PopoverAppearance, reduceTransparency: Bool,
               customBackground: UIView?) {
        radius = max(0, appearance.cornerRadius)
        cornerMask = appearance.maskedCorners
        let material = resolveMaterial(appearance, reduceTransparency: reduceTransparency,
                                       hasCustomBackground: customBackground != nil)
        // Keep the foreground independent from effect compositing and never
        // reparent it during style changes, especially with an active text field.
        effectView.effect = material.effect
        effectView.backgroundColor = material.color
        effectView.clipsToBounds = !material.isGlass
        configureEffectCorners()
        if customBackgroundView !== customBackground {
            customBackgroundView?.removeFromSuperview()
            customBackgroundView = customBackground
            if let customBackground { effectView.contentView.insertSubview(customBackground, at: 0) }
        }
        foregroundView.layer.cornerRadius = radius
        foregroundView.layer.maskedCorners = cornerMask
        foregroundView.layer.borderWidth = max(appearance.borderWidth,
                                               UIAccessibility.isDarkerSystemColorsEnabled ? 1 : 0)
        foregroundView.layer.borderColor = appearance.borderColor.resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = appearance.shadowColor.resolvedColor(with: traitCollection).cgColor
        layer.shadowOpacity = material.isGlass && !appearance.addsShadowToLiquidGlass ? 0 : appearance.shadowOpacity
        layer.shadowRadius = appearance.shadowRadius
        layer.shadowOffset = appearance.shadowOffset
        grabber.isHidden = !appearance.showsGrabber
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView.frame = bounds
        effectView.layoutIfNeeded()
        let contentBounds = bounds
        customBackgroundView?.frame = effectView.contentView.bounds
        foregroundView.frame = contentBounds
        grabber.frame = CGRect(x: contentBounds.midX - 18, y: 7, width: 36, height: 5)
        let top: CGFloat = grabber.isHidden ? 0 : 20
        contentContainer.frame = CGRect(x: 0, y: top, width: contentBounds.width,
                                        height: max(0, contentBounds.height - top - bottomContentInset))
        layer.shadowPath = layer.shadowOpacity > 0
            ? UIBezierPath(roundedRect: bounds, byRoundingCorners: Self.rectCorners(from: cornerMask),
                           cornerRadii: CGSize(width: radius, height: radius)).cgPath : nil
    }

    private func configureEffectCorners() {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // Tell the glass renderer its actual shape rather than trimming a
            // rectangular glass effect with a rounded mask on its parent.
            effectView.cornerConfiguration = glassCornerConfiguration()
            return
        }
        #endif
        effectView.layer.cornerRadius = radius
        effectView.layer.maskedCorners = cornerMask
        effectView.clipsToBounds = true
    }

    /// 玻璃统一圆角沿用 uniformCorners；非对称圆角按角单独配置，nil 表示该角不圆，
    /// 保持玻璃原生轮廓而不退回层裁切。
    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private func glassCornerConfiguration() -> UICornerConfiguration {
        guard cornerMask != Self.allCornerMask else {
            return .uniformCorners(radius: .fixed(Double(radius)))
        }
        let rounded = UICornerRadius.fixed(Double(radius))
        return .corners(
            topLeftRadius: cornerMask.contains(.layerMinXMinYCorner) ? rounded : nil,
            topRightRadius: cornerMask.contains(.layerMaxXMinYCorner) ? rounded : nil,
            bottomLeftRadius: cornerMask.contains(.layerMinXMaxYCorner) ? rounded : nil,
            bottomRightRadius: cornerMask.contains(.layerMaxXMaxYCorner) ? rounded : nil)
    }
    #endif

    private static let allCornerMask: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                                     .layerMinXMaxYCorner, .layerMaxXMaxYCorner]

    /// CACornerMask 与 UIRectCorner 的角顺序一致，逐一映射避免依赖原始值对齐。
    private static func rectCorners(from mask: CACornerMask) -> UIRectCorner {
        var corners: UIRectCorner = []
        if mask.contains(.layerMinXMinYCorner) { corners.insert(.topLeft) }
        if mask.contains(.layerMaxXMinYCorner) { corners.insert(.topRight) }
        if mask.contains(.layerMinXMaxYCorner) { corners.insert(.bottomLeft) }
        if mask.contains(.layerMaxXMaxYCorner) { corners.insert(.bottomRight) }
        return corners
    }

    private func resolveMaterial(_ appearance: PopoverAppearance, reduceTransparency: Bool,
                                 hasCustomBackground: Bool) -> (effect: UIVisualEffect?, color: UIColor, isGlass: Bool) {
        if hasCustomBackground { return (nil, .clear, false) }
        if reduceTransparency { return (nil, appearance.backgroundColor, false) }
        switch appearance.material {
        case .solid: return (nil, appearance.backgroundColor, false)
        case .blur(let style): return (UIBlurEffect(style: style), .clear, false)
        case .liquidGlass, .automatic:
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                let effect = UIGlassEffect(style: .regular)
                effect.tintColor = appearance.tintColor
                return (effect, .clear, true)
            }
            #endif
            if case .automatic = appearance.material { return (nil, appearance.backgroundColor, false) }
            return (UIBlurEffect(style: .systemMaterial), .clear, false)
        }
    }
}
