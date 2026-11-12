# BonePopoverKit

BonePopoverKit 是面向 iOS 15+ 的 UIKit 弹窗组件，通过 Swift Package 集成，无第三方依赖。提供确认框、输入框、操作列表、Toast 和自定义内容，支持页面内展示、独立 Window、导航、液态玻璃、动画与触摸穿透。

内容样式、材质外观、布局、动画和关闭交互分别配置，可在显示期间调整。通过可继承的 `BonePopoverView` 和内容容器 `baseView` 构建业务弹窗，组件负责展示、布局和关闭生命周期。

完整接入、参数和示例见 [BonePopoverKit 使用说明](Docs/UsageGuide.md)。

## 安装

Xcode → File → Add Package Dependencies，输入仓库地址 `https://github.com/taokoplay/BonePopoverKit.git`，选择 `main` 分支，再给 App target 添加 `BonePopoverKit` product。其他 Swift Package 可使用：

```swift
.package(url: "https://github.com/taokoplay/BonePopoverKit.git", branch: "main")
```

本地开发也可通过 Add Local 选择组件目录，或使用 `.package(path: "../BonePopoverKit")`。

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

`show(from:)` 在指定控制器的 view 内展示；覆盖导航栏/标签栏时可传入容器控制器。需要跨业务 Window 显示时使用 `show(over: sourceWindow)`，或 `show(in: scene)` 明确目标 Scene。无参 `show()` 在恰好一个前台活动 Scene 时自动选择上下文并创建独立 Window；`show(isNav: true)` 创建带导航容器的独立 Window。所有入口返回 `Bool`，展示失败不会遗留窗口。完整说明见 [独立 Window 模式](Docs/WindowPresentation.md)。

```swift
let alert = BoneAlertView(title: "独立窗口", message: "显示在源窗口所属的 Scene 中。") {}
alert.configuration.window.level = .alert - 1
alert.configuration.window.stacking = .aboveManagedPopovers
if let sourceWindow = view.window {
    alert.show(over: sourceWindow)
}
```

`configuration.window` 支持窗口层级、叠加、key 接管和导航容器策略。本次展示使用窗口配置的快照，修改在下次展示生效；内容样式、材质、布局与触摸配置支持显示期间更新。

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

操作列表默认在标题左侧显示向下箭头关闭按钮（阅读器默认头部，40 × 40 点命中区，辅助功能标识 `popover-close`），标题居中；`showsCloseButton = false` 可隐藏，`closeButton` 可定制图标与辅助功能属性。

## Toast 提示

`BoneToastView` 支持顶部长条、底部长条和中间方块，以及成功、失败、提示、加载中四种类型。四种类型均默认停留 **2 秒**后自动关闭，无遮罩，允许继续操作底层页面。按需选择一种用法：

```swift
BoneToastView(message: "保存成功", type: .success, style: .top).show(from: self)
BoneToastView(message: "操作失败", type: .failure, style: .bottom, duration: 3).show(from: self)
BoneToastView(message: "有新消息", type: .info, style: .center).show(from: self)
BoneToastView(message: "正在加载", type: .loading, style: .center).show(from: self)
```

成功显示绿色勾选，失败显示红色叉号，提示显示蓝色信息图标，加载中显示系统进度圈。省略 `type` 时默认 `.info`。通过 `duration` 设置任意停留秒数，设为 `0` 可持续显示，之后调用 `hidden()` 关闭；显示期间修改 `duration` 或 `type` 会重新计时。

长条最大宽度 560 点、高度随内容调整；居中方块从 160 点起随内容增大，默认最大 280 × 280 点，空间不足时继续缩小，超长内容在内部滚动。图标或进度圈在长条 leading 侧、方块文字上方，`image` 可覆盖非加载类型的图标。

显示期间修改 `message` / `image` 会重新测量。样式通过 `configuration.contentStyle` 和 `configuration.appearance` 调整；同样支持 `show(over:)` 等独立 Window 入口，默认保留当前 key Window。完整参数和持续加载示例见 [Toast 使用说明](Docs/UsageGuide.md#toast)。

## 配置参数

每个字段单独列出名称、默认值和用途。通过 `popover.configuration` 访问下列配置分组：

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `contentStyle` | 内容样式 | `PopoverContentStyle()` | 字体、颜色、对齐、内部边距和按钮排列；完整字段见下表。 |
| `appearance` | 材质外观 | `PopoverAppearance()` | 材质、圆角、边框、阴影和遮罩；完整字段见下表。 |
| `layout` | 面板布局 | `PopoverLayout()` | 位置、尺寸、外部间距和区域避让，见 [布局参数](Docs/UsageGuide.md#layout)。 |
| `animation` | 展示与关闭动画 | 随配置预设设置 | 时长、阻尼和隐藏端点，见 [动画参数](Docs/UsageGuide.md#animation)。 |
| `window` | 独立窗口 | `PopoverWindowConfiguration()` | 层级、叠加、key 和导航容器，见 [窗口参数](Docs/WindowPresentation.md#窗口配置)。 |

背景、点击、穿透、滑动与辅助功能开关见 [配置字段总表](Docs/UsageGuide.md#reference)。基础配置与各预设的默认值区别见 [布局预设](Docs/UsageGuide.md#layout)。

### 内容样式 `configuration.contentStyle`

下表默认值来自 `PopoverContentStyle()`。字体接受基础 `UIFont`，尺寸和间距单位为点。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `titleFont` | 标题字体 | `.boldSystemFont(ofSize: 18)` | 确认框、输入框和操作列表的标题基础字体。 |
| `messageFont` | 正文字体 | `.systemFont(ofSize: 17)` | 正文和说明文字的基础字体。 |
| `buttonFont` | 按钮字体 | `.systemFont(ofSize: 17)` | 确认、取消及操作列表按钮的基础字体。 |
| `inputFont` | 输入字体 | `.systemFont(ofSize: 17)` | 单字段输入框的基础字体。 |
| `titleColor` | 标题颜色 | `.label` | 标题文字颜色，支持系统深浅色。 |
| `messageColor` | 正文颜色 | `.secondaryLabel` | 正文文字颜色，支持系统深浅色。 |
| `titleAlignment` | 标题对齐 | `.left` | 独立控制标题对齐，支持左、中、右等 `NSTextAlignment` 取值。 |
| `messageAlignment` | 正文对齐 | `.natural` | 按正文书写方向对齐，也可明确指定。 |
| `contentInsets` | 内容内边距 | 四边各 24 | 内容与面板内容区域之间的留白，不包含抓手。 |
| `titleToContentSpacing` | 标题到内容间距 | 14 | 标题到正文或输入框的距离。 |
| `contentToButtonsSpacing` | 内容到按钮间距 | 14 | 正文或输入框到按钮区域；无正文操作列表中为标题到首个按钮的距离。 |
| `buttonSpacing` | 按钮间距 | 12 | 横排、竖排按钮及操作列表动作之间的距离。 |
| `buttonContentInsets` | 按钮内边距 | 上下 12，leading/trailing 各 16 | 按钮文字和图标周围的留白。 |
| `adjustsFontForContentSizeCategory` | 动态字号 | `true` | 随系统文字大小缩放基础字体；设为 `false` 使用固定字号。 |
| `buttonLayout` | Alert 按钮排列 | `.automatic` | 支持自动、等宽横排、等宽竖排；操作列表始终竖排。 |

### 材质外观 `configuration.appearance`

下表默认值来自 `PopoverAppearance()`；`.classic` 将材质设为纯色、圆角设为 16 点。`.bottomSheet` 采用阅读器默认样式：纯色 `systemBackground` 表面、圆角 16 点仅顶部两角、无抓手、无背景遮罩且不叠加阴影。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `material` | 面板材质 | `.automatic` | 支持自动、纯色、系统模糊和原生液态玻璃。 |
| `backgroundColor` | 面板背景色 | `.secondarySystemBackground` | 用于纯色材质及降低透明度时的回退。 |
| `tintColor` | 玻璃染色 | `nil` | 原生液态玻璃的染色；模糊回退效果可能不同。 |
| `cornerRadius` | 面板圆角 | 24 点 | 面板内容与材质轮廓的圆角半径。 |
| `maskedCorners` | 圆角作用角 | 四角 | 仅这些角应用圆角，映射 `CALayer.maskedCorners`；底部 sheet 通常只圆顶部两角。 |
| `borderColor` | 边框颜色 | `.separator` | 面板前景边框的颜色。 |
| `borderWidth` | 边框宽度 | 0 点 | 设置大于 0 时显示配置边框；增强对比度时系统可提高宽度。 |
| `shadowColor` | 阴影颜色 | `.black` | 自定义面板阴影的颜色。 |
| `shadowOpacity` | 阴影不透明度 | 0.16 | 自定义阴影的浓度。 |
| `shadowRadius` | 阴影模糊半径 | 24 点 | 自定义阴影的模糊范围。 |
| `shadowOffset` | 阴影偏移 | `(width: 0, height: 8)` | 自定义阴影的水平与垂直偏移。 |
| `addsShadowToLiquidGlass` | 玻璃额外阴影 | `false` | 是否在原生玻璃系统阴影外叠加上述自定义阴影。 |
| `backdropColor` | 遮罩颜色 | `.black` | 面板外部背景遮罩的颜色。 |
| `backdropOpacity` | 遮罩不透明度 | 0.32 | 遮罩的视觉浓度，不控制点击是否穿透。 |
| `showsGrabber` | 显示抓手 | `false` | 是否在面板内容上方显示拖拽指示条。 |

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

内置布局：`.bottomSheet`、`.centerDialog`、`.topBanner`、`.sidePanel`。`.bottomSheet` 为阅读器默认底栏：贴底、无外部留白，宽度取所在可用区并受 560 点上限；圆角 16 点仅顶部两角、纯色 `systemBackground`、无遮罩无抓手无阴影，0.15 秒底部滑入，内置标题默认居中。顶部通知默认是模态浮层，不自动消失；可独立开启外部触摸穿透。

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

直接打开 `Examples/BonePopoverDemo/BonePopoverDemo.xcodeproj`，选择 iPhone / iPad / Duo 模拟器运行。示例支持 5 种外观、5 种动画选择，以及 18 个场景，含运行时切换风格、注入横/竖折叠区域、自定义 Alert 尺寸、长内容上限、竖排按钮、窄空间回退、自定义字体与间距、即时调整内容样式、多窗口展示和三种 Toast。导航栏“标题对齐”菜单可选择左对齐、居中、右对齐，再打开确认框或操作列表预览。

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
