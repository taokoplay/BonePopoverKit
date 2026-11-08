import UIKit

/// Physical finger directions, unaffected by right-to-left language settings.
/// Use .automatic to derive the outward direction from the panel's placement.
public struct PopoverSwipeDirection: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let none = Self([])
    public static let left = Self(rawValue: 1 << 0)
    public static let right = Self(rawValue: 1 << 1)
    public static let up = Self(rawValue: 1 << 2)
    public static let down = Self(rawValue: 1 << 3)
    public static let automatic = Self(rawValue: 1 << 4)
    public static let horizontal: Self = [.left, .right]
    public static let vertical: Self = [.up, .down]
    public static let all: Self = [.horizontal, .vertical]

    func resolved(for placement: PopoverPlacement, isRightToLeft: Bool) -> Self {
        var result = intersection(.all)
        if contains(.automatic) {
            switch placement {
            case .bottom: result.insert(.down)
            case .top: result.insert(.up)
            case .leading: result.insert(isRightToLeft ? .right : .left)
            case .trailing: result.insert(isRightToLeft ? .left : .right)
            case .center: result.formUnion(.all)
            }
        }
        return result
    }

    static func dominant(in motion: CGPoint, allowed: Self) -> Self? {
        guard motion.x.isFinite, motion.y.isFinite, motion != .zero else { return nil }
        let direction: Self
        if abs(motion.x) > abs(motion.y) { direction = motion.x < 0 ? .left : .right }
        else { direction = motion.y < 0 ? .up : .down }
        return allowed.contains(direction) ? direction : nil
    }

    var vector: CGPoint {
        switch self {
        case .left: return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        case .up: return CGPoint(x: 0, y: -1)
        default: return CGPoint(x: 0, y: 1)
        }
    }

    func projection(of point: CGPoint) -> CGFloat { point.x * vector.x + point.y * vector.y }

    func exitTransform(panel: CGRect, container: CGRect) -> CGAffineTransform {
        switch self {
        case .left: return .init(translationX: container.minX - panel.maxX, y: 0)
        case .right: return .init(translationX: container.maxX - panel.minX, y: 0)
        case .up: return .init(translationX: 0, y: container.minY - panel.maxY)
        default: return .init(translationX: 0, y: container.maxY - panel.minY)
        }
    }

    @MainActor
    func canTakeOver(_ scrollView: UIScrollView) -> Bool {
        guard scrollView.isScrollEnabled else { return true }
        let inset = scrollView.adjustedContentInset
        let minimum = CGPoint(x: -inset.left, y: -inset.top)
        let maximum = CGPoint(x: max(minimum.x, scrollView.contentSize.width - scrollView.bounds.width + inset.right),
                              y: max(minimum.y, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom))
        switch self {
        case .left: return scrollView.contentOffset.x >= maximum.x - 1
        case .right: return scrollView.contentOffset.x <= minimum.x + 1
        case .up: return scrollView.contentOffset.y >= maximum.y - 1
        default: return scrollView.contentOffset.y <= minimum.y + 1
        }
    }
}
