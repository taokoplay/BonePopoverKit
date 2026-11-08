import UIKit

/// The effect owns its silhouette. Only foreground content is clipped, so native
/// glass highlights and shadows can extend beyond the surface without being cut off.
@MainActor
final class PopoverSurfaceView: UIView {
    let contentContainer = UIView()
    let grabber = UIView()
    private let effectView = UIVisualEffectView()
    private let foregroundView = UIView()
    private var customBackgroundView: UIView?
    private var radius: CGFloat = 24

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
                                        height: max(0, contentBounds.height - top))
        layer.shadowPath = layer.shadowOpacity > 0
            ? UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath : nil
    }

    private func configureEffectCorners() {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // Tell the glass renderer its actual shape rather than trimming a
            // rectangular glass effect with a rounded mask on its parent.
            effectView.cornerConfiguration = .uniformCorners(radius: .fixed(Double(radius)))
            return
        }
        #endif
        effectView.layer.cornerRadius = radius
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
