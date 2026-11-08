import UIKit

/// 独立窗口的叠加规则，只影响本 SDK 在同一个 Scene 中管理的窗口。
public enum PopoverWindowStacking: Sendable {
    /// 使用配置的最低层级，并保证高于源窗口和同 Scene 的已有弹窗。
    case aboveManagedPopovers
    /// 严格使用配置层级，便于配合 App 自己的通知、遮罩等窗口约定。
    case fixed
}

/// 独立窗口是否接管键盘等事件的主要接收权。
public enum PopoverWindowKeyPolicy: Sendable {
    /// 展示时接管 key，关闭时恢复有效窗口及可恢复的输入焦点。
    case takeAndRestore
    /// 保留当前 key Window；适用于无需键盘输入的浮层。
    case preserveCurrent
}

/// 独立窗口中的控制器容器类型。
public enum PopoverWindowContainer: Sendable {
    /// 透明普通宿主，不创建导航栈。
    case plain
    /// UIKit 导航容器，根页面默认隐藏导航栏，业务可通过 navigationController push/pop。
    case navigation
}

/// 独立 Window 的创建选项。展示时保存快照，显示期间修改会在下次展示生效。
/// 内容样式、材质、布局及触摸配置仍通过 configuration 的对应属性实时更新。
@MainActor
public struct PopoverWindowConfiguration {
    /// 最低窗口层级，默认 alert - 1；自动叠加时可能按源窗口及已有弹窗继续提高。
    public var level: UIWindow.Level = .alert - 1
    /// 默认自动叠加；fixed 不自动提高层级。
    public var stacking: PopoverWindowStacking = .aboveManagedPopovers
    /// 默认接管并恢复 key Window；preserveCurrent 模式不支持文本输入接管。
    public var keyPolicy: PopoverWindowKeyPolicy = .takeAndRestore
    /// 默认普通宿主，navigation 提供独立导航栈。
    public var container: PopoverWindowContainer = .plain

    /// 创建默认独立窗口选项；可在展示前按业务需要修改各项策略。
    public init() {}
}
