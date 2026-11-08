import UIKit

/// 主线程上的窗口协调器。每个 Scene 单独保存有序会话，不参与业务弹窗排队或去重。
@MainActor
final class PopoverWindowCoordinator: NSObject {
    static let shared = PopoverWindowCoordinator()

    private struct SceneRecords {
        weak var scene: UIWindowScene?
        var sessions: [PopoverWindowSession] = []
    }
    private var records: [ObjectIdentifier: SceneRecords] = [:]

    private override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(sceneDisconnected(_:)), name: UIScene.didDisconnectNotification, object: nil)
        for name in [UIWindow.didBecomeHiddenNotification, UIWindow.didBecomeVisibleNotification,
                     UIWindow.didBecomeKeyNotification, UIWindow.didResignKeyNotification] {
            center.addObserver(self, selector: #selector(windowsChanged(_:)), name: name, object: nil)
        }
    }

    func sessions(in scene: UIWindowScene) -> [PopoverWindowSession] {
        records[ObjectIdentifier(scene)]?.sessions ?? []
    }

    func sourceWindow(in scene: UIWindowScene) -> UIWindow? {
        if let key = scene.keyWindow {
            if let managed = key as? PopoverWindow { return managed.session?.sourceWindow }
            return isValid(key, in: scene) ? key : nil
        }
        // 没有 key 时只接受唯一可识别的业务窗口，避免误选其他浮层。
        let candidates = scene.windows.filter { !($0 is PopoverWindow) && isValid($0, in: scene) && $0.windowLevel == .normal }
        return candidates.count == 1 ? candidates.first : nil
    }

    func businessSource(for window: UIWindow) -> UIWindow? {
        guard let scene = window.windowScene, isValid(window, in: scene) else { return nil }
        let source = (window as? PopoverWindow)?.session?.sourceWindow ?? window
        return isValid(source, in: scene) ? source : nil
    }

    /// 非有限值或提高层级后溢出均拒绝展示；不修改其他窗口的层级。
    func resolvedLevel(_ config: PopoverWindowConfiguration, over source: UIWindow, in scene: UIWindowScene) -> UIWindow.Level? {
        guard config.level.rawValue.isFinite else { return nil }
        if config.stacking == .fixed { return config.level }
        let highest = sessions(in: scene).filter { $0.state != .finished && !$0.window.isHidden }
            .map { $0.window.windowLevel.rawValue }.max() ?? source.windowLevel.rawValue
        let floor = max(highest, source.windowLevel.rawValue)
        let next = max(config.level.rawValue, floor + 1)
        guard next.isFinite, next > floor else { return nil }
        return UIWindow.Level(rawValue: next)
    }

    func insert(_ session: PopoverWindowSession, in scene: UIWindowScene) {
        let key = ObjectIdentifier(scene)
        var value = records[key] ?? SceneRecords(scene: scene)
        value.sessions.append(session)
        records[key] = value
    }

    @discardableResult
    func remove(_ session: PopoverWindowSession, restoringFocus: Bool) -> Bool {
        let window = session.window
        let scene = window.windowScene
        let wasKey = window.isKeyWindow
        let others = scene.map { sessions(in: $0).filter { $0 !== session } } ?? []
        // 下层先关闭时，把上层的恢复链改接到有效前驱，避免稍后恢复到已销毁窗口。
        for other in others where other.previousKeyWindow === window {
            other.previousKeyWindow = session.previousKeyWindow ?? session.sourceWindow
            other.previousFirstResponder = session.previousFirstResponder
        }
        if let scene {
            let key = ObjectIdentifier(scene)
            records[key]?.sessions.removeAll { $0 === session }
            if records[key]?.sessions.isEmpty == true { records.removeValue(forKey: key) }
        }
        window.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
        window.session = nil
        // 显式脱离 Scene 的窗口注册，释放 UIKit 对已关闭窗口的关联。
        window.windowScene = nil
        var restored = false
        if wasKey, restoringFocus, let scene, scene.activationState != .unattached {
            // 隐藏窗口可同步触发应用观察者，期间可能已展示新窗口或主动切换 key。
            // 返回后重新读取当前 Scene 状态，尊重已经完成的交接。
            let remaining = sessions(in: scene).filter { $0.state == .visible && isValid($0.window, in: scene) }
            let managed = remaining.enumerated().filter { $0.element.configuration.keyPolicy == .takeAndRestore }
                .max { lhs, rhs in
                    lhs.element.window.windowLevel == rhs.element.window.windowLevel
                        ? lhs.offset < rhs.offset : lhs.element.window.windowLevel < rhs.element.window.windowLevel
                }?.element.window
            let fallback = managed ?? [session.previousKeyWindow, session.sourceWindow].compactMap { $0 }
                .first { isValid($0, in: scene) && $0.canBecomeKey }
            let current = scene.keyWindow.flatMap { isValid($0, in: scene) && $0 !== window ? $0 : nil }
            if let target = current ?? fallback {
                if current == nil { target.makeKey() }
                restored = target.isKeyWindow
                if restored, let field = session.previousFirstResponder, field.window === target,
                   PopoverWindowSession.firstResponder(in: target) == nil, field.canBecomeFirstResponder {
                    field.becomeFirstResponder()
                }
            }
        }
        for other in others { other.configurationDidChange() }
        return restored
    }

    /// 相同 level 时 SDK 会话按展示顺序判断上下关系，避免把后展示的上层窗口当作穿透目标。
    func isBelow(_ target: UIWindow, session: PopoverWindowSession, in scene: UIWindowScene) -> Bool {
        guard target !== session.window else { return false }
        if target.windowLevel != session.window.windowLevel { return target.windowLevel < session.window.windowLevel }
        let ordered = sessions(in: scene)
        if let managed = target as? PopoverWindow, let targetSession = managed.session,
           let targetIndex = ordered.firstIndex(where: { $0 === targetSession }),
           let ownIndex = ordered.firstIndex(where: { $0 === session }) { return targetIndex < ownIndex }
        let windows = scene.windows
        guard let targetIndex = windows.firstIndex(where: { $0 === target }),
              let ownIndex = windows.firstIndex(where: { $0 === session.window }) else { return false }
        return targetIndex < ownIndex
    }

    func isValid(_ window: UIWindow, in scene: UIWindowScene) -> Bool {
        window.windowScene === scene && !window.isHidden && window.alpha > 0.01 && window.rootViewController != nil
    }

    @objc private func sceneDisconnected(_ note: Notification) {
        guard let scene = note.object as? UIWindowScene else { return }
        // 先取快照，回调中允许展示/关闭其他 Scene 的弹窗。
        for session in sessions(in: scene) {
            session.popover?.dismissPopover(animated: false, reason: .hostRemoved)
            session.finish(restoringFocus: false)
        }
        records.removeValue(forKey: ObjectIdentifier(scene))
    }

    @objc private func windowsChanged(_ note: Notification) {
        let changed = note.object as? UIWindow
        let all = records.values.flatMap(\.sessions)
        // 源窗口可在穿透点击的控件动作中关闭；下一轮统一清理，不在命中阶段产生副作用。
        if note.name == UIWindow.didBecomeHiddenNotification {
            for session in all where session.state == .visible && (session.sourceWindow === changed || session.window === changed) {
                DispatchQueue.main.async { [weak session] in
                    guard let session, session.state == .visible,
                          session.sourceWindow?.isHidden != false || session.window.isHidden else { return }
                    session.popover?.dismissPopover(animated: false, reason: .hostRemoved)
                }
            }
        }
        for session in all { session.configurationDidChange() }
    }
}
