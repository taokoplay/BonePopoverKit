# BonePopoverKit

面向 iOS 15+ 的 UIKit 弹窗 Swift Package。沿用 `BonePopoverView: UIViewController`、`baseView`、`show()`、`hidden()` 的基本使用方式，将内容样式、材质外观、布局和动画分别配置。无第三方依赖。

完整接入与配置说明见 [BonePopoverKit 使用说明](Docs/UsageGuide.md)，包含统一字体与间距、标题对齐、液态玻璃、背景与穿透组合、多方向关闭、自定义内容和常见问题。

这是新 SDK 的可运行初版，**不是旧 CLPopoverManager 及全部业务子类的二进制或源码兼容替代品**。现有项目未被自动迁移。先阅读 [项目清点](Docs/Inventory.md) 和 [迁移说明](Docs/Migration.md)。

## 安装

Xcode → File → Add Package Dependencies → Add Local，选择本目录，给 App target 添加 `BonePopoverKit` product。包内依赖可使用：

```swift
.package(path: "../BonePopoverKit")
```

本地目录目前没有远程发布地址或版本 tag；不要填写臆造的 Git URL。公开发布前由维护者确定仓库和许可证。

最低部署版本 iOS 15；Package tools version 5.9。新 API 同时受编译器条件与系统版本保护：

| 能力 | 条件 | 低版本行为 |
| --- | --- | --- |
| 经典 / 自定义纯色、系统模糊 | iOS 15+ | 原生可用 |
| `.automatic` 外观 | 用 iOS 26+ SDK 构建且运行 iOS 26+ | 纯色经典材质 |
| `.liquidGlass` 外观 | 用 iOS 26+ SDK 构建且运行 iOS 26+ | `.systemMaterial` 模糊 |
| Duo 系统折叠 / 摄像头保留区域 | Xcode 27.1 / Swift 6.4、iOS 27.1+ | 使用当前容器和四边安全区 |
| Reduce Transparency | 系统开启降低透明度 | 自动纯色 |
| Reduce Motion | 系统开启减弱动态效果 | 短时淡入淡出 |

旧编译器回退路径尚未在独立旧 Xcode 中构建；当前编译验证环境见 [验证记录](Docs/Validation.md)。

## 最短接入

```swift
import BonePopoverKit

let alert = BoneAlertView(title: "保存更改", message: "将当前配置保存到项目？") {
    // 确认回调在弹窗移除之后执行。
}
alert.configuration.appearance = .liquidGlass
alert.titleAlignment = .center // .left / .center / .right，默认 .left
alert.show(from: self)
```

`show(from:)` 在指定控制器的 view 内展示；覆盖导航栏/标签栏时可传入容器控制器。需要跨业务 Window 显示时使用 `show(over: sourceWindow)`，或 `show(in: scene)` 明确目标 Scene。无参 `show()` 恢复旧版独立 Window 用法，只在恰好一个前台活动 Scene 时自动选择上下文；`show(isNav: true)` 提供独立导航容器。所有入口返回 `Bool`，展示失败不会遗留窗口。完整层级、key 恢复与生命周期说明见 [独立 Window 模式](Docs/WindowPresentation.md)。

```swift
let alert = BoneAlertView(title: "独立窗口", message: "显示在源窗口所属的 Scene 中。") {}
alert.configuration.window.level = .alert - 1
alert.configuration.window.stacking = .aboveManagedPopovers
if let sourceWindow = view.window {
    alert.show(over: sourceWindow)
}
```

`configuration.window` 还包含 `.takeAndRestore` / `.preserveCurrent` 的 key 策略，以及 `.plain` / `.navigation` 容器选项。窗口配置在本次展示时保存快照，下次展示应用变更；内容样式、材质、布局与触摸配置继续实时更新。`show()` / `show(in:)` 与本包早期版本相比改为独立窗口；页面模式明确使用 `show(from:)`。

```swift
let input = BoneAlertView(title: "项目名称", placeholder: "输入名称") { name in
    print(name)
}
input.keyboardType = .default
input.textField.isSecureTextEntry = false
input.show(from: self)

let sheet = BoneActionSheetView(title: "项目操作", actions: [
    PopoverAction("分享", image: UIImage(systemName: "square.and.arrow.up")) {},
    PopoverAction("删除", role: .destructive) {}
])
sheet.show(from: self)
```

## 任意内容与预设布局

```swift
let content = MyContentView() // 使用完整的 Auto Layout 垂直约束链
var config = PopoverConfiguration.bottomSheet
config.appearance = .frosted
config.layout.maximumWidth = 600
config.layout.height = .fraction(0.7)
config.animation = .slide(.bottom, duration: 0.35, dampingRatio: 0.9)
let popover = BonePopoverView(contentView: content, configuration: config)
popover.show(from: self)
```

内置布局：`.bottomSheet`、`.centerDialog`、`.topBanner`、`.sidePanel`。顶部通知默认是模态浮层，不自动消失；可独立开启外部触摸穿透。

内置确认框、输入框和操作列表共用 `configuration.contentStyle: PopoverContentStyle`。标题默认 `UIFont.boldSystemFont(ofSize: 18)`，正文默认 17 点，四边内容内边距默认 24 点。字体、颜色、对齐和内部间距可统一复用，也可在显示期间逐项修改并自动重新测量：

```swift
let alert = BoneAlertView(title: "保存设置", message: "确认保存当前配置？") {}
var style = PopoverContentStyle()
style.titleFont = UIFont.boldSystemFont(ofSize: 18)
style.messageFont = UIFont.systemFont(ofSize: 16)
style.titleAlignment = .center
style.messageAlignment = .left
style.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
style.titleToContentSpacing = 12
style.contentToButtonsSpacing = 20
style.buttonSpacing = 12
alert.configuration.contentStyle = style
alert.show(from: self)
```

同一份样式还包含 `buttonFont`、`inputFont`、`buttonContentInsets` 和 `buttonLayout`。默认启用 Dynamic Type；传入基础 `UIFont` 即可，需要固定字号时将 `style.adjustsFontForContentSizeCategory` 设为 `false`。全部字段与默认值见 [字体、对齐与内容间距](Docs/UsageGuide.md#titles)。

标题仍位于内容顶部，`titleAlignment` 和 Alert 的 `buttonLayout` 便利属性直接读写同一份样式。整份替换 `configuration` 会同时替换样式；先选预设再设置定制项。直接设置 label 字体或对齐会在后续样式刷新时被覆盖。更新样式保留按钮标题、图标和输入内容及焦点。Alert 默认两个按钮左右等宽，取消在左、确认在右；操作列表仍逐个竖排。内容栈不会重复叠加外部已避让的安全区。

`BoneAlertView`（确认框和输入框）默认左右外部间距为 **32 点**，面板最大尺寸为 **420 × 600 点**。在 iPad 等大屏上不会无限放大，在窄窗口和 Duo 折叠区域内仍按可用空间缩小。可在显示前或显示期间设置：

```swift
let alert = BoneAlertView(title: "项目设置", message: "确认使用当前设置？") {}
alert.horizontalMargin = 40
alert.maximumSize = CGSize(width: 480, height: 560)
alert.show(from: self)
```

外部间距与 24 点内部内容间距不同。这两个属性是底层 `configuration.layout` 的便利入口；如需整份覆盖配置，应先选择预设，再设置它们。通用 `.centerDialog` 和操作列表仍保持原默认值。

Alert 的 `buttonLayout` 默认 `.automatic`：通常左右排列，空间不足、按钮标题过长或辅助功能大字号时自动竖排，竖排保持确认在上、取消在下。可在显示前或显示期间明确设置为 `.horizontal` / `.vertical`。

尺寸支持 `.content`、`.fixed`、`.fraction`、`.fill`，并接受最大宽高、四边独立间距、显示位置和区域偏好。超过可用高度的内容默认可滚动；已自行管理滚动的内容可设 `scrollsOverflow = false`，并实现自己的内容布局。

动画支持四向滑入、淡入淡出、缩放、弹簧、无动画和自定义隐藏端点。程序关闭沿配置路径退出；手势关闭沿锁定的手指方向退出，不改写入场动画。关闭可以打断出现动画，拖拽不足或被拦截时回弹。居中预设默认禁用拖拽，开启后支持指定方向。

```swift
popover.configuration.animation = PopoverAnimation(duration: 0.3, dampingRatio: 0.9) { panel, container, rtl in
    PopoverVisualState(
        transform: CGAffineTransform(translationX: 0, y: 32).scaledBy(x: 0.96, y: 0.96),
        opacity: 0
    )
}
```

## 背景、外部点击与滑动关闭

这些配置相互独立，支持在弹窗显示期间修改：

```swift
popover.configuration.showsBackdrop = false          // 隐藏背景遮罩
popover.configuration.dismissOnBackdropTap = true    // 仍可点击外部关闭
popover.configuration.allowsEventPenetration = false // 拦截外部点击，不传给底层

popover.configuration.allowsDragToDismiss = true
popover.configuration.allowedSwipeDirections = [.left, .right, .up, .down]
popover.configuration.swipeThreshold = 100           // 关闭所需的投影距离（点）
```

把 `appearance.backdropOpacity` 设为 `0` 同样不会禁用外部点击层。背景显示仅影响视觉；`showsBackdrop = false`、背景颜色透明和关闭开关可以自由组合。

需要同时操作底层页面时开启穿透：

```swift
popover.configuration.allowsEventPenetration = true
popover.configuration.autoHideWhenPenetrated = true // 同一次外部点击也关闭弹窗
```

穿透模式下外部点击交给底层页面：`autoHideWhenPenetrated = false` 保留弹窗，`true` 在真实外部点击结束后请求关闭。`dismissOnBackdropTap` 只控制不穿透时的外部点击，不与穿透模式叠加。外部点击、穿透自动关闭、滑动和辅助功能退出请求经过 `shouldDismiss`；程序关闭及内置确认、取消按钮的直接关闭不经过该拦截。若拦截穿透关闭，底层页面仍会收到点击。穿透仅发生在传入 `show(from:)` 的容器区域内。开穿透时辅助功能也不再把该浮层当作模态。

`allowedSwipeDirections` 支持 `.all`、`.horizontal`、`.vertical`、`.none`，以及任意上下左右组合。显式方向是物理方向，不随 RTL 翻转。默认 `.automatic` 按位置选择：底部向下、顶部向上、两侧向外；居中开启拖拽后为四向。

慢速拖动必须超过 `swipeThreshold`（默认 100 点），快速滑动使用“当前位置 + 松手速度 × 0.15 秒”的投影距离判断；取消或明显反向收回会回弹。方向在开始时锁定，不在拖动途中改道。滚动内容优先处理还未到边界的手势；控件上的触摸保留给按钮、输入框等控件。自定义内容可继续覆盖手势协调钩子。

非穿透弹窗展示期间会暂时停用宿主导航控制器的边缘返回手势，以及 iOS 26 起的整页返回手势，避免未允许的右滑触发底层页面返回。关闭后恢复原启用状态；叠加弹窗在最后一个关闭后恢复。开启穿透时允许底层页面按其原行为处理导航。

## 扩展与运行时修改

```swift
final class BookSettingsSheet: BonePopoverView {
    init() {
        super.init(nibName: nil, bundle: nil)
        configuration = .bottomSheet
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // 向 baseView 添加业务控件，或调用 setContentView。
    }

    override func preferredPopoverSize(fitting availableSize: CGSize) -> CGSize {
        CGSize(width: availableSize.width, height: 360)
    }

    override func notificationHidden(type: CLPopoverDismissType) {
        // 停止业务请求或播放等。
    }
}
```

可直接修改 `configuration` 切换外观、圆角、边框、阴影、遮罩、布局和动画；`customBackgroundView` 可完全替换材质背景。玻璃模式请保持 `baseView` 和业务内容背景透明，避免遮住系统材质。

Liquid Glass 的圆角直接配置在 `UIVisualEffectView.cornerConfiguration`，由系统渲染完整的玻璃轮廓；文字和按钮在独立前景层中单独裁切，避免材质合成影响清晰度。原生玻璃默认使用系统阴影，避免叠加普通卡片阴影。如需额外阴影，设 `appearance.addsShadowToLiquidGlass = true` 后再配置 `shadowOpacity` 等参数。经典、模糊和旧系统回退仍使用可配置阴影。

内容尺寸变化后调用 `invalidatePopoverLayout()`。`preferredContentSize` 可作为明确的内容尺寸，手动布局可覆盖 `preferredPopoverSize(fitting:)`。配置 `shouldDismiss` 可拦截点击背景、拖拽和辅助功能关闭；程序调用 `hidden()` / `dismissPopover()` 始终可结束当前展示。

```swift
popover.configuration.appearance = .classic
popover.shouldDismiss = { reason in /* 业务校验 */ true }
popover.hidden { /* 已移除后执行；重复关闭请求的 completion 各执行一次 */ }
```

## Duo 自动适配

不判断设备名称，不读取 `UIScreen.main`。容器每次布局使用当前 bounds、四边安全区、键盘和保留区域；iOS 27.1 上在 `updateConstraints()` 查询 `.division` / `.occlusion`，由 UIKit 跟踪其变化。只避开活动区域，系统 frame 已含边距，不重复加 margins。

默认在面积接近的两块区域中偏向 trailing/bottom，可设置 `layout.regionPreference`，或通过 `layout.anchorPoint` 选择与触发控件相关的区域。几何选择不推断铰链角度或设备姿态。

`reservedRegionProvider` 允许应用覆盖区域查询，用于自定义显示设备或可重复测试。示例中的注入折叠场景明确属于模拟几何，不等于验证了真实 Duo 的全部姿态。

## 示例与测试

直接打开 `Examples/BonePopoverDemo/BonePopoverDemo.xcodeproj`，选择 iPhone / iPad / Duo 模拟器运行。示例支持 5 种外观、5 种动画选择，以及 15 个场景，含运行时切换风格、注入横/竖折叠区域、自定义 Alert 尺寸、长内容上限、竖排按钮、窄空间回退、自定义字体与间距、即时调整内容样式和多窗口展示。导航栏“标题对齐”菜单可选择左对齐、居中、右对齐，再打开任意内置弹窗预览。

导航栏“关闭交互”打开交互体验页，提供背景/外部点击/穿透开关、自动/四向/单向滑动选择、50/100/200 点阈值，以及底层点击计数。菜单“交互方案”可快速验证透明外部关闭、穿透并关闭、仅左滑等组合。

“多窗口展示”提供双业务 Window、自动/固定层级、叠加与乱序关闭、输入、穿透计数、导航 push/pop 及第二 Scene 激活。UI 测试可用 `--window-demo` 直接进入，真实 Scene 与窗口生命周期测试使用 Demo 托管的 `BonePopoverWindowTests` scheme，运行方式见 [独立 Window 模式](Docs/WindowPresentation.md)。

重新生成工程：

```sh
xcodegen generate --spec Examples/BonePopoverDemo/project.yml
```

运行包测试（将设备名替换为本机可用模拟器）：

```sh
xcodebuild test -scheme BonePopoverKit \
  -destination 'platform=iOS Simulator,name=iPhone Duo'
```

运行真实点击测试：

```sh
xcodebuild test -project Examples/BonePopoverDemo/BonePopoverDemo.xcodeproj \
  -scheme BonePopoverDemo -destination 'platform=iOS Simulator,name=iPhone Duo'
```

测试使用 XCTest，以便与较早 Swift 工具链及 UIKit 测试基础设施配合。普通 `swift test` 的 macOS 目标不支持 UIKit；请使用 iOS destination。
