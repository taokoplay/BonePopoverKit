import UIKit

public struct PopoverVisualState {
    public var transform: CGAffineTransform
    public var opacity: CGFloat

    public init(transform: CGAffineTransform = .identity, opacity: CGFloat = 1) {
        self.transform = transform
        self.opacity = opacity
    }
}

/// Customize the hidden endpoint; the visible endpoint is identity/opacity 1.
/// UIKit property animators provide interruption and symmetric presentation/dismissal.
@MainActor
public struct PopoverAnimation {
    public enum Edge: Sendable { case top, bottom, leading, trailing }
    public var duration: TimeInterval
    public var dampingRatio: CGFloat
    public var hiddenState: (_ panel: CGRect, _ container: CGRect, _ isRightToLeft: Bool) -> PopoverVisualState

    public init(duration: TimeInterval = 0.32, dampingRatio: CGFloat = 1,
                hiddenState: @escaping (CGRect, CGRect, Bool) -> PopoverVisualState) {
        self.duration = max(0, duration)
        self.dampingRatio = max(0.1, min(1, dampingRatio))
        self.hiddenState = hiddenState
    }

    public static func slide(_ edge: Edge, duration: TimeInterval = 0.32,
                             dampingRatio: CGFloat = 1) -> Self {
        Self(duration: duration, dampingRatio: dampingRatio) { panel, container, rtl in
            var dx: CGFloat = 0
            var dy: CGFloat = 0
            switch edge {
            case .top: dy = container.minY - panel.maxY
            case .bottom: dy = container.maxY - panel.minY
            case .leading: dx = rtl ? container.maxX - panel.minX : container.minX - panel.maxX
            case .trailing: dx = rtl ? container.minX - panel.maxX : container.maxX - panel.minX
            }
            return PopoverVisualState(transform: .init(translationX: dx, y: dy))
        }
    }

    public static var fade: Self {
        Self(duration: 0.2) { _, _, _ in PopoverVisualState(opacity: 0) }
    }

    /// 缩放淡入；默认从 0.92 倍开始，旧 `.scale` 等价于 `.scale()`。
    /// 阅读器类应用需要更明显的收放时可传 0.8 等比例，比例会被夹在 0...1。
    public static func scale(_ factor: CGFloat = 0.92, duration: TimeInterval = 0.25,
                             dampingRatio: CGFloat = 1) -> Self {
        let clamped = factor.isFinite ? min(1, max(0, factor)) : 0.92
        return Self(duration: duration, dampingRatio: dampingRatio) { _, _, _ in
            PopoverVisualState(transform: .init(scaleX: clamped, y: clamped), opacity: 0)
        }
    }

    public static var scale: Self { scale() }

    public static var spring: Self {
        Self(duration: 0.4, dampingRatio: 0.82) { _, _, _ in
            PopoverVisualState(transform: .init(scaleX: 0.88, y: 0.88), opacity: 0)
        }
    }

    public static var none: Self {
        Self(duration: 0) { _, _, _ in PopoverVisualState() }
    }
}
