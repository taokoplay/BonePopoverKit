import UIKit

/// 独立弹窗窗口。命中测试仅决定事件归属，不在查询过程中关闭弹窗。
@MainActor
final class PopoverWindow: UIWindow {
    weak var session: PopoverWindowSession?
    /// 创建时固定的 key 策略；窗口退出过程中不能随弱会话释放而改变。
    var acceptsKey = true

    override var canBecomeKey: Bool {
        acceptsKey
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01 else { return nil }
        if let session, session.isPopoverRootVisible,
           session.popover?.configuration.allowsEventPenetration == true,
           !session.containsPanel(point, in: self) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
