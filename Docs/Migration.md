# 从 BonePopoverView 迁移

本次只创建新包，没有修改旧项目。建议先迁移一个独立确认框和一个底部业务弹窗，验证后再逐步移除各 App 内的旧副本。

## 接入顺序

1. 给 App target 添加本地 Swift Package `BonePopoverKit`。
2. 在要迁移的文件中 `import BonePopoverKit`。旧同名类还在 target 中时，临时使用 `BonePopoverKit.BonePopoverView` / `BonePopoverKit.BoneAlertView`，避免解析到旧类型。
3. 将构造配置改为 `PopoverConfiguration`，把内容加入 `baseView`。
4. 把“整屏坐标/屏幕宽高/键盘高度推算”移到内容局部坐标，使用 `preferredPopoverSize(fitting:)` 返回所需大小。
5. 根据覆盖范围选择 `show(from:)` 页面模式，或 `show(over: sourceWindow)` 独立窗口，验证回调、键盘、滚动、横竖屏、深浅色和 Duo。
6. 只有该 target 的全部旧引用迁移完成后，才移除旧组件目录及不再使用的依赖。

## 保留与替换

| 旧入口/行为 | 新 SDK |
| --- | --- |
| `BonePopoverView: CLPopoverController` | 仍是可继承 UIViewController；`BonePopoverView` 现在是 `open` |
| `baseView` | 保留；其 bounds 是弹窗内容区域，不再代表整屏 |
| `popupType = .alert / .sheet / .fadeIn` | 保留，映射默认位置/动画；新代码推荐配置布局预设 |
| `show()` | 独立 Window，单一前台活动 Scene 自动选择宿主，返回 Bool |
| `show(isNav:)` | 保留导航兼容入口，使用包内 UIKit 导航容器；不依赖 App 的 MainTabNavController |
| `hidden(completion)` | 保留；动画结束并移除控制器后执行 completion |
| `notificationHidden(type:)` | 保留 open 钩子；旧 `CLPopoverDismissType` 为新原因枚举的 typealias |
| `notificationDismissComplete` | 保留，每次实际关闭执行一次 |
| `notificationPopoverRemoved` | 未直接保留；涉及选择取消/任务清理时需按本包回调顺序适配，不能机械重命名 |
| `shouldBeginSwipeToDismiss` / `shouldRecognizeSwipeToDismissSimultaneously` | 保留为 open 手势钩子，可额外协调 WebKit 等业务滚动 |
| `isShowKeyboard` / `keyboardFrameEnd` | 保留只读状态；通常无需业务层重复避让 |
| `config.backgroundHideDuration` | `configuration.animation.duration` |
| `config.isShowBackgroud` | `configuration.showsBackdrop`，独立于外部点击关闭；`backdropOpacity = 0` 也支持点击 |
| `config.openKeyListener` | `configuration.layout.avoidsKeyboard`，默认开启 |
| `config.swipeToDismissEnabled` | `configuration.allowsDragToDismiss`；居中预设默认关，开启后可滑动 |
| `config.allowedSwipeDirections` / `swipeThreshold` | `configuration.allowedSwipeDirections` / `swipeThreshold`；支持四向组合与关闭投影距离 |
| `baseView.backgroundColor` / 圆角 | 优先配置 `appearance`，避免不透明业务底色覆盖玻璃 |
| 内置标题 / 正文字体、对齐和内部间距 | 统一放入 `configuration.contentStyle: PopoverContentStyle`；标题默认 18 点粗体、正文 17 点 |
| `showAnimation` / `dismissAnimation` | `PopoverAnimation` 自定义隐藏端点、时长、阻尼 |
| `CLPopoverManager`、queue/interrupt/replace/unique、优先级 | 本版未实现；由 App 协调展示顺序，不能假定自动排队/去重 |
| `allowsEventPenetration` / `autoHideWhenPenetrated` | `configuration` 内保留同名开关：外部触摸穿透，及穿透点击后是否关闭 |
| `windowLevel` | `configuration.window.level`；默认 alert - 1，自动叠加高于源窗口/同 Scene SDK 弹窗；fixed 使用精确层级 |
| 业务会员徽标、图片加载、WebKit/阅读逻辑 | 留在 App 的内容视图或子类 |

`PopoverDismissReason` 在原 `.normal/.penetration/.slide` 外还有 `.accessibility/.hostRemoved`。旧穷举 switch 需要处理新情况。`.penetration` 同时表示被拦截的外部点击关闭和穿透点击后自动关闭；是否穿透由配置决定。

旧子类若覆盖 `show()`，需将返回类型调整为 `Bool` 并返回 `super.show()` 的结果。`hidden(_:)` 保持可覆盖。新关闭钩子统一在移除后发出；依赖旧动画结束、移除、业务 completion 三个不同阶段的代码应明确调整时序。

新增的默认 `.automatic` 滑动方向保留按位置向外退出的行为。迁移原有明确方向请直接赋值，例如 `[.left, .down]`；需要全面禁用方向用 `.none`。`swipeThreshold` 默认 100 点，慢拖按距离、快滑按“距离 + 速度 × 0.15 秒”判定，比旧版单纯距离多了速度投影。穿透打开时，`autoHideWhenPenetrated` 决定是否随外部点击关闭，`dismissOnBackdropTap` 不会吞掉底层事件。

## 独立窗口模式迁移

本包当前版本恢复旧组件的独立 Window 能力。`show()` 和 `show(in:)` 相比本包早期版本改为独立窗口；保留页面内展示行为时改用 `show(from:)`。多业务 Window 建议使用 `show(over: sourceWindow)`，明确绑定其所属 Scene；SDK 不读取 AppDelegate.window、固定窗口标识或全局首个活跃 Scene。

窗口创建选项位于 `configuration.window`，含 level、stacking、keyPolicy 和 container，本次展示使用快照，下次展示应用变更。默认 takeAndRestore 接管并恢复有效 key Window；无需键盘的浮层可 preserveCurrent。导航 push/pop 沿用 UIKit，关闭弹窗会清理整个窗口导航栈。旧 queue/interrupt/replace/unique 仍需由业务协调，未自动迁入。

新包通过按 Scene 的有序会话管理窗口所有权，关闭完成回调在窗口移除、状态清理和 key 恢复之后执行。同实例重显、下层先关闭、源窗口隐藏及 Scene 断开都有统一清理路径。配置与示例见 [独立 Window 模式](WindowPresentation.md)。

## 手动布局子类

旧写法经常把 `baseView` 放到整屏底部，再直接修改 `view.frame.origin.y` 做动画。新容器负责位置和动画，业务层只布局内部控件：

```swift
import UIKit
import BonePopoverKit

final class ReaderOptionsSheet: BonePopoverKit.BonePopoverView {
    private let label = UILabel()

    init() {
        super.init(nibName: nil, bundle: nil)
        configuration = .bottomSheet
        configuration.appearance = .classic // 第一次迁移先保留熟悉的风格
        configuration.layout.maximumWidth = 560
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "阅读设置"
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        baseView.addSubview(label)
    }

    override func preferredPopoverSize(fitting availableSize: CGSize) -> CGSize {
        CGSize(width: availableSize.width, height: 320)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        label.frame = CGRect(x: 24, y: 24, width: max(0, baseView.bounds.width - 48), height: 44)
    }
}
```

已有 PinLayout 可以继续用于 `baseView` 内的业务控件，但不要再用全局屏幕尺寸定位弹窗本身。自带 UITableView/UICollectionView/WKWebView 的大内容应设置明确高度，并决定是否关闭外层 `scrollsOverflow`，避免重复滚动容器。

## 同名预设差异

- Wecat、StudyPlan、TaokoManage、ValuablePicture 和旧包的确认/输入 `BoneAlertView`：可使用新包相同 initializer labels；配置与回调时机需核对。
- ParsingBook 的 `BoneEasyAlertView`：对应新 `BoneAlertView`；密码配置在公开的 `textField.isSecureTextEntry`，按钮可通过 `confirmButton` / `cancelButton` 自定义。旧有所有便捷属性不保证逐一同名。
- ParsingBook 的 `BoneAlertView(title:message:) + addButton/loading`：与本版同名类语义不同。可改用 `BoneActionSheetView` 的 actions，或继续将业务多按钮/loading UI 作为自定义内容；loading 不自动结束、不应伪装成普通确认回调。
- `BoneDrawerSheetView` 的分组/单选/多选/拖拽排序和 `customCellProvider`：本版通用操作列表未实现这些业务接口。保留原内容逻辑，迁移到新基类；不能以 typealias 冒充完整兼容。
- `BoneInputAlertView` 多字段、`BonePromptView`：作为自定义内容迁移；单字段输入已有内置实现。

## 统一内容样式

确认框、输入框和操作列表的 `UIFont`、颜色、对齐、内容内边距、标题/正文/按钮间距统一由 `PopoverContentStyle` 管理。原 `titleAlignment` 和 Alert 的 `buttonLayout` 便利入口继续可用，但现在直接读写 `configuration.contentStyle`；整份覆盖 `configuration` 会同时替换它们。先选择 `.centerDialog`、`.bottomSheet` 等配置，再定制样式。

默认标题改为 `UIFont.boldSystemFont(ofSize: 18)`，正文基础字号仍为 17。Dynamic Type 默认开启；设置 `adjustsFontForContentSizeCategory = false` 可固定字号。迁移原来直接赋值 `titleLabel.font`、`messageLabel.font` 或对齐的代码时，将其改为 `configuration.contentStyle.titleFont`、`messageFont`、`titleAlignment`、`messageAlignment`，避免后续样式刷新覆盖。按钮标题和图标继续使用公开控件修改。

自定义业务子类的控件由业务继续管理；需要跟随此样式时覆盖 `applyContentStyle()`，在控件构建完成后主动调用一次。完整设置示例和默认值见 [使用说明第 4 节](UsageGuide.md#titles)。

## 回调与生命周期契约

旧 Wecat/旧 Package 有“关闭动画刚启动就调用 completion”的行为。新包统一在实际移除之后执行，因此回调可安全发起下一次展示。连续多次 hidden 的各个 completion 均会执行，但关闭通知仅一次。

出现动画可以被关闭打断；中途关闭不会触发已取消的 `onDidShow`。宿主离开窗口时自动结束展示，原因 `.hostRemoved`。业务清理应放在关闭钩子中，而不是假定用户一定点确认或取消。

先确认 `show` 返回 true 再等待业务结果。不要同时把同一实例交给旧 CLPopoverManager 与新 SDK。新包通过控制器 containment 展示，因此应使用 `hidden` / `dismissPopover` 关闭，不能用系统 `dismiss(animated:)` 代替。

## 主题、Duo 与验收

配置 `.classic` 可暂时保持纯色；再逐屏选择 `.frosted`、`.liquidGlass` 或 `.automatic`。系统颜色随宿主环境适配，业务主题可通过 `appearance` 提供颜色和材质，SDK 不读取 AppColor 或 BoneThemeManager。

Duo 需要 App 也使用支持该设备的 SDK 构建；最低系统设为 iOS 15 不妨碍使用新 SDK。容器能避开保留区域，但无法自动修正业务内容内部的硬编码宽度和超过可用空间的横向排布。

迁移每个场景时验证：普通 iPhone、iPad 窄分屏、Duo 展开/折叠与旋转，输入键盘和长文本、动态字号、VoiceOver 关闭、减弱动态效果/降低透明度，以及连续展示关闭。当前包的已执行检查和未执行项见 [Validation.md](Validation.md)。

## 新增可选项（不设置即旧行为）

迁移时不需要为新字段做任何修改，以下入口只在显式赋值时生效：

| 入口 | 用途 | 默认 |
| --- | --- | --- |
| `alert.confirmTitle` / `.cancelTitle`、`sheet.cancelTitle` / `.closeAccessibilityLabel`、`toast.typeDescriptions`、`popover.backdropAccessibilityLabel` | 各组件自己的文案入口 | `nil`，使用原中文文案 |
| `configuration.interfaceStyle` | 固定弹层浅色/深色，替代旧包的 `userInterfaceStyleOverride` | `.unspecified`，跟随宿主 |
| `contentStyle.closeButtonImage` / `.closeButtonSize` | 替换操作列表关闭按钮图标与命中区 | `nil` / 40 点 |
| `PopoverAnimation.scale(_:)` | 调整缩放动画幅度（旧包写死 0.8） | `.scale` = 0.92 |
| `alert.confirmTitle` / `.cancelTitle`、`sheet.cancelTitle` | 运行期修改按钮文案 | `nil`，回退 SDK/初始化默认 |

完整对照见 [阅读器对照](ReaderParity.md)。
