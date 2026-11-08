import UIKit

/// 跨 Window 的真实点击观察。只观察实际接收触摸的窗口，不转发事件、不在 hitTest 中关闭。
@MainActor
final class PopoverOutsideTapObserver: NSObject, UIGestureRecognizerDelegate {
    private final class Observation {
        weak var window: UIWindow?
        let recognizer: UITapGestureRecognizer
        init(window: UIWindow, recognizer: UITapGestureRecognizer) {
            self.window = window
            self.recognizer = recognizer
        }
    }
    private weak var session: PopoverWindowSession?
    private var observations: [ObjectIdentifier: Observation] = [:]

    init(session: PopoverWindowSession) {
        self.session = session
        super.init()
    }

    func updateWindows() {
        guard let session, let scene = session.window.windowScene else { invalidate(); return }
        let targets = scene.windows.filter {
            !$0.isHidden && $0.alpha > 0.01 && $0.rootViewController != nil &&
                PopoverWindowCoordinator.shared.isBelow($0, session: session, in: scene)
        }
        let targetIDs = Set(targets.map(ObjectIdentifier.init))
        for key in Array(observations.keys) where !targetIDs.contains(key) {
            if let observation = observations.removeValue(forKey: key) {
                observation.window?.removeGestureRecognizer(observation.recognizer)
            }
        }
        for window in targets where observations[ObjectIdentifier(window)] == nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapEnded(_:)))
            tap.delegate = self
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            window.addGestureRecognizer(tap)
            observations[ObjectIdentifier(window)] = Observation(window: window, recognizer: tap)
        }
    }

    func invalidate() {
        for observation in observations.values { observation.window?.removeGestureRecognizer(observation.recognizer) }
        observations.removeAll()
    }

    @objc private func tapEnded(_ tap: UITapGestureRecognizer) {
        guard tap.state == .ended, let session else { return }
        // 让本次底层控件动作先完成；会话身份检查保证不会关闭回调中重显的新弹窗。
        DispatchQueue.main.async { [weak session] in session?.requestOutsideDismissal() }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let session, session.isPopoverRootVisible, let source = touch.view?.window else { return false }
        return !session.containsPanel(touch.location(in: source), in: source)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}
