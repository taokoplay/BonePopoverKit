import UIKit

/// Custom contained popovers are not system presentations. Suspend navigation's
/// return gestures while a modal popover is present, including iOS 26's full-page
/// back pan. Reference counts preserve the original state for stacked popovers.
@MainActor
final class PopoverNavigationGestureGuard {
    private struct Pause {
        weak var gesture: UIGestureRecognizer?
        let wasEnabled: Bool
        var count: Int
    }
    private static var pauses: [ObjectIdentifier: Pause] = [:]
    private var identifiers: [ObjectIdentifier] = []

    init(navigationController: UINavigationController) {
        var gestures = [navigationController.interactivePopGestureRecognizer].compactMap { $0 }
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), let gesture = navigationController.interactiveContentPopGestureRecognizer {
            gestures.append(gesture)
        }
        #endif
        for gesture in gestures {
            let key = ObjectIdentifier(gesture)
            guard !identifiers.contains(key) else { continue }
            identifiers.append(key)
            if var existing = Self.pauses[key], existing.gesture === gesture {
                existing.count += 1
                Self.pauses[key] = existing
            } else {
                Self.pauses[key] = Pause(gesture: gesture, wasEnabled: gesture.isEnabled, count: 1)
            }
            gesture.isEnabled = false
        }
    }

    func invalidate() {
        for key in identifiers {
            guard var pause = Self.pauses[key] else { continue }
            pause.count -= 1
            if pause.count == 0 {
                pause.gesture?.isEnabled = pause.wasEnabled
                Self.pauses.removeValue(forKey: key)
            } else {
                Self.pauses[key] = pause
            }
        }
        identifiers.removeAll()
    }
}
