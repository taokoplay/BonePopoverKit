import UIKit

public struct PopoverLayoutContext {
    public var bounds: CGRect
    public var safeAreaInsets: UIEdgeInsets
    public var excludedFrames: [CGRect]
    public var isRightToLeft: Bool

    public init(bounds: CGRect, safeAreaInsets: UIEdgeInsets = .zero,
                excludedFrames: [CGRect] = [], isRightToLeft: Bool = false) {
        self.bounds = bounds
        self.safeAreaInsets = safeAreaInsets
        self.excludedFrames = excludedFrames
        self.isRightToLeft = isRightToLeft
    }
}

/// Pure geometry shared by UIKit presentations and tests. No device-name checks.
public enum PopoverLayoutEngine {
    public static func availableFrame(in context: PopoverLayoutContext, layout: PopoverLayout) -> CGRect {
        let safe = inset(context.bounds, by: context.safeAreaInsets)
        var candidates = [safe]
        for exclusion in context.excludedFrames where !exclusion.isEmpty && !exclusion.isNull {
            candidates = candidates.flatMap { subtract(exclusion, from: $0) }
        }
        candidates = candidates.filter { $0.width > 0 && $0.height > 0 }
        guard !candidates.isEmpty else {
            return CGRect(origin: safe.origin, size: .zero)
        }
        let largestArea = candidates.map { $0.width * $0.height }.max() ?? 0
        // An explicit source point must remain eligible even in a smaller pane.
        let viable = layout.anchorPoint == nil
            ? candidates.filter { $0.width * $0.height >= largestArea * 0.45 }
            : candidates
        let selected = viable.max { lhs, rhs in
            score(lhs, context: context, layout: layout, largestArea: largestArea)
                < score(rhs, context: context, layout: layout, largestArea: largestArea)
        } ?? safe
        return inset(selected, by: layout.margins)
    }

    public static func frame(in context: PopoverLayoutContext, layout: PopoverLayout,
                             contentSize: CGSize) -> CGRect {
        let area = availableFrame(in: context, layout: layout)
        let width = dimension(layout.width, content: contentSize.width,
                              available: area.width, maximum: layout.maximumWidth)
        let height = dimension(layout.height, content: contentSize.height,
                               available: area.height, maximum: layout.maximumHeight)
        var x = area.midX - width / 2
        var y = area.midY - height / 2
        switch layout.placement {
        case .bottom: y = area.maxY - height
        case .top: y = area.minY
        case .center: break
        case .leading: x = context.isRightToLeft ? area.maxX - width : area.minX
        case .trailing: x = context.isRightToLeft ? area.minX : area.maxX - width
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func dimension(_ value: PopoverDimension, content: CGFloat,
                          available: CGFloat, maximum: CGFloat) -> CGFloat {
        let requested: CGFloat
        switch value {
        case .content: requested = content
        case .fixed(let points): requested = points
        case .fraction(let fraction): requested = available * min(1, max(0, fraction))
        case .fill: requested = available
        }
        return max(0, min(available, maximum, requested.isFinite ? requested : 0))
    }

    private static func inset(_ rect: CGRect, by edges: UIEdgeInsets) -> CGRect {
        let left = min(rect.width, max(0, edges.left))
        let top = min(rect.height, max(0, edges.top))
        return CGRect(x: rect.minX + left, y: rect.minY + top,
                      width: max(0, rect.width - left - max(0, edges.right)),
                      height: max(0, rect.height - top - max(0, edges.bottom)))
    }

    private static func subtract(_ exclusion: CGRect, from area: CGRect) -> [CGRect] {
        let cut = area.intersection(exclusion)
        guard !cut.isNull && !cut.isEmpty else { return [area] }
        // Each candidate is a complete usable rectangle, not a fragment union.
        return [
            CGRect(x: area.minX, y: area.minY, width: cut.minX - area.minX, height: area.height),
            CGRect(x: cut.maxX, y: area.minY, width: area.maxX - cut.maxX, height: area.height),
            CGRect(x: area.minX, y: area.minY, width: area.width, height: cut.minY - area.minY),
            CGRect(x: area.minX, y: cut.maxY, width: area.width, height: area.maxY - cut.maxY)
        ].filter { $0.width > 0 && $0.height > 0 }
    }

    private static func score(_ rect: CGRect, context: PopoverLayoutContext,
                              layout: PopoverLayout, largestArea: CGFloat) -> CGFloat {
        let area = rect.width * rect.height / max(1, largestArea)
        if let anchor = layout.anchorPoint {
            let dx = max(rect.minX - anchor.x, 0, anchor.x - rect.maxX)
            let dy = max(rect.minY - anchor.y, 0, anchor.y - rect.maxY)
            return area - (dx * dx + dy * dy)
        }
        let x = (rect.midX - context.bounds.minX) / max(1, context.bounds.width)
        let y = (rect.midY - context.bounds.minY) / max(1, context.bounds.height)
        let trailing = context.isRightToLeft ? 1 - x : x
        switch layout.regionPreference {
        case .largest: return area
        case .automatic: return area + 0.25 * (trailing + y)
        case .leading: return area + 2 * (1 - trailing)
        case .trailing: return area + 2 * trailing
        case .top: return area + 2 * (1 - y)
        case .bottom: return area + 2 * y
        }
    }
}
