# BonePopoverKit

BonePopoverKit 是面向 iOS 15+ 的 UIKit 弹窗组件，通过 Swift Package 集成，无第三方依赖。提供确认框、输入框、基于 UITableView 的底部操作列表、Toast 和自定义内容，支持页面内展示、独立 Window、导航、液态玻璃、动画与触摸穿透。

内容样式、材质外观、布局、动画和关闭交互分别配置，可在显示期间调整。通过可继承的 `BonePopoverView` 和内容容器 `baseView` 构建业务弹窗，组件负责展示、布局和关闭生命周期。

完整接入、参数和示例见 [使用说明](Docs/UsageGuide.md)，`v0.1.0` 的功能调整与升级影响见 [更新日志](CHANGELOG.md#v0.1.0)。

| 文档 | 内容 |
| --- | --- |
| [使用说明](Docs/UsageGuide.md) | 安装、内置组件、参数默认值与完整示例 |
| [更新日志](CHANGELOG.md) | 各版本的变更、修复与不兼容 API 调整 |
| [迁移指南](Docs/Migration.md#action-sheet-migration) | 旧操作列表 API 替换及已有项目接入 |
| [窗口说明](Docs/WindowPresentation.md) | 页面 / Window 展示范围、导航与 Scene |
| [阅读器对照](Docs/ReaderParity.md) | 阅读器接口、默认值与适配边界 |
| [验证记录](Docs/Validation.md#unified-operation-list) | 最近实现验证结果、历史证据与未验收范围 |

## 安装

Xcode → File → Add Package Dependencies，输入仓库地址 `https://github.com/taokoplay/BonePopoverKit.git`，选择 **Up to Next Minor Version**、最低版本 `0.1.0`，再给 App target 添加 `BonePopoverKit` product。其他 Swift Package 可使用：

```swift
.package(url: "https://github.com/taokoplay/BonePopoverKit.git", .upToNextMinor(from: "0.1.0"))
```

本地开发也可通过 Add Local 选择组件目录，或使用 `.package(path: "../BonePopoverKit")`。需要跟随开发分支时使用 `.package(url: "https://github.com/taokoplay/BonePopoverKit.git", branch: "main")`。

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

`show(from:)` 在内容页的 view 内展示；传入导航/标签容器时自动选择当前内容页，不改变导航返回栈或标签列表。需要覆盖导航栏/标签栏或跨业务 Window 显示时使用 `show(over: sourceWindow)`，或 `show(in: scene)` 明确目标 Scene。无参 `show()` 在恰好一个前台活动 Scene 时自动选择上下文并创建独立 Window；`show(isNav: true)` 创建带导航容器的独立 Window。所有入口返回 `Bool`，展示失败不会遗留窗口。完整说明见 [独立 Window 模式](Docs/WindowPresentation.md)。

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

let sheet = BoneDrawerSheetView(title: "项目操作", message: "选择要执行的操作")
sheet.addButton(text: "分享", icon: UIImage(systemName: "square.and.arrow.up"),
                accessibilityIdentifier: "sheet-share") { share() }
sheet.addButton(text: "刷新状态", dismissesPopover: false) { refresh() }
sheet.addButton(text: "删除", style: .destructive) { delete() }
sheet.show(from: self)
```

底部操作列表统一使用 `BoneDrawerSheetView`：先建面板，再逐行 `addButton(text:...)`。普通行默认先关闭再回调；`dismissesPopover: false` 立即回调并保持面板。`addButton` 返回 `Void`，行的辅助功能标识通过参数传入。默认不附加取消行，左侧向下箭头负责关闭。

单选、多选、拖动排序和固定高度滚动都是同一组件的变体。选择型分区需要显式打开右侧确定按钮，再用 `selectAction` 接收提交结果：

```swift
let sheet = BoneDrawerSheetView(title: "阅读设置")
sheet.addButton(text: "平移", value: "0", inSection: .singleSelect("翻页", true))
sheet.addButton(text: "仿真", value: "1", inSection: .singleSelect("翻页", false))
sheet.addButton(text: "浅色", value: "light", inSection: .multipleSelect("主题", false))
sheet.addButton(text: "深色", value: "dark", inSection: .multipleSelect("主题", false))
sheet.showsConfirmButton = true
sheet.selectAction { selections in print(selections) } // [(text: String, value: String)]
sheet.show(from: self)
```

右侧按钮默认隐藏，`showsConfirmButton = true` 后用于提交；`confirmTitle` 可改“确定”文案，`trailingButton` 可改图标，`onTrailingButtonTap` 可接管点击。`.drag("分区标题")` 仅允许同分区排序；长列表通过 `sheetConfig.maximumListHeight`（默认 500 点）限制列表区域并内部滚动，详见[选择、排序与滚动变体](Docs/UsageGuide.md#sheet-variants)。

默认面板为 `systemGroupedBackground`，行背景为 `secondarySystemGroupedBackground`，顶部两角 16 点、无阴影、无背景遮罩，显示抓手。标题为 17 点 semibold 并居中，说明文字为 14 点，多行正文通过 `message` 传入。表头左右留白 `sheetConfig.headerInset` 为 16 点，标题上下留白 `headerTopSpacing` 为 10 点，到列表的 `listTopSpacing` 为 16 点。贴底时材质铺满底部安全区，内容仍避让安全区。

左侧关闭按钮默认显示（`showsCloseButton = true`），40 × 40 点命中区、距面板左边 16 点，辅助功能标识为 `drawer-close`。公开的 `titleLabel`、`messageLabel`、`closeButton` 可定制 UIKit 属性；持久的字体、颜色和对齐通过 `contentStyle` 配置。行字体、行高和分隔线通过 `sheetConfig` 配置，默认 16 点粗体、55 点行高；`contentStyle.buttonFont` / `buttonSpacing` / `buttonLayout` 用于 Alert，不控制表格行。

旧 `BoneActionSheetView` 和 `PopoverAction` 已删除，不提供兼容 alias；旧 `actions` / `addAction`、返回 `UIButton` 的 `addButton`、`actionButtons` / `cancelButton` / `cancelTitle` 需按[迁移说明](Docs/Migration.md#action-sheet-migration)调整。

内置文案由各组件提供入口：`alert.confirmTitle` / `alert.cancelTitle`（默认“确认”“取消”）、`sheet.confirmTitle`（默认“确定”）、`sheet.closeAccessibilityLabel`（默认“关闭”）、`toast.typeDescriptions`（默认“成功”“失败”“提示”“加载中”）、`popover.backdropAccessibilityLabel`（默认 `NSLocalizedString("Dismiss")`）。主题与动画同样可选：`configuration.interfaceStyle` 默认 `.unspecified` 跟随宿主，设为 `.light` / `.dark` 可固定弹层外观；`PopoverAnimation.scale(0.8)` 可调整缩放幅度，`.scale` 仍是 0.92。与阅读器旧基类的逐项对照见 [阅读器对照](Docs/ReaderParity.md)。

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
| `titleFont` | 标题字体 | `.boldSystemFont(ofSize: 18)` | 确认框和输入框的标题基础字体；操作列表默认 17 点 semibold。 |
| `messageFont` | 正文字体 | `.systemFont(ofSize: 17)` | 正文和说明文字的基础字体；操作列表默认 14 点。 |
| `buttonFont` | 按钮字体 | `.systemFont(ofSize: 17)` | Alert 确认、取消按钮的基础字体；操作列表行字体使用 `sheetConfig.fontSize`。 |
| `inputFont` | 输入字体 | `.systemFont(ofSize: 17)` | 单字段输入框的基础字体。 |
| `titleColor` | 标题颜色 | `.label` | 标题文字颜色，支持系统深浅色。 |
| `messageColor` | 正文颜色 | `.secondaryLabel` | 正文文字颜色，支持系统深浅色。 |
| `titleAlignment` | 标题对齐 | `.left` | 独立控制标题对齐；操作列表默认 `.center`。 |
| `messageAlignment` | 正文对齐 | `.natural` | 按正文书写方向对齐，也可明确指定。 |
| `contentInsets` | 内容内边距 | 四边各 24 | 内容区域留白，不包含抓手；操作列表默认 top/leading/trailing 为 0、bottom 为 20。 |
| `titleToContentSpacing` | 标题到内容间距 | 14 | Alert 标题到正文或输入框的距离；操作列表有说明时控制标题行底部到说明的间距，无说明时改用 `sheetConfig.listTopSpacing`。 |
| `contentToButtonsSpacing` | 内容到按钮间距 | 14 | Alert 正文或输入框到按钮区域的距离。 |
| `buttonSpacing` | 按钮间距 | 12 | Alert 横排、竖排按钮之间的距离；不控制表格行间距。 |
| `buttonContentInsets` | 按钮内边距 | 上下 12，leading/trailing 各 16 | Alert 按钮文字和图标周围的留白。 |
| `closeButtonImage` | 操作列表关闭按钮图标 | `nil` | `nil` 使用内置 12 点 `chevron.down`；替换后仍沿用标题色。 |
| `closeButtonSize` | 操作列表关闭按钮边长 | 40 点 | 方形命中区；非法值回退 40 点。 |
| `adjustsFontForContentSizeCategory` | 动态字号 | `true` | 随系统文字大小缩放基础字体；设为 `false` 使用固定字号。 |
| `buttonLayout` | Alert 按钮排列 | `.automatic` | 支持自动、等宽横排、等宽竖排；不参与操作列表的 UITableView 布局。 |

### 材质外观 `configuration.appearance`

下表默认值来自 `PopoverAppearance()`；`.classic` 将材质设为纯色、圆角设为 16 点。通用 `.bottomSheet` 采用纯色 `systemBackground` 表面、圆角 16 点仅顶部两角、无抓手、无背景遮罩且不叠加阴影；`BoneDrawerSheetView` 在此基础上使用 `systemGroupedBackground` 并显示抓手。

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
| `backdropGlass` | 玻璃遮罩 | `false` | 是否给遮罩叠加玻璃模糊；与不透明度独立，可只虚化不压暗。 |
| `backdropGlassStyle` | 玻璃遮罩材质 | `.systemUltraThinMaterial` | 玻璃开启时的模糊材质。 |
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

内置布局：`.bottomSheet`、`.centerDialog`、`.topBanner`、`.sidePanel`。通用 `.bottomSheet` 贴底、无外部留白，宽度取所在可用区并受 560 点上限；圆角 16 点仅顶部两角、纯色 `systemBackground`、无遮罩无抓手无阴影，0.15 秒底部滑入，内置标题默认居中。操作列表 `BoneDrawerSheetView` 使用分组面板底色并显示抓手。顶部通知默认是模态浮层，不自动消失；可独立开启外部触摸穿透。

确认框、输入框和操作列表的标题与说明使用 `configuration.contentStyle: PopoverContentStyle`。Alert 标题默认 18 点粗体、正文 17 点、四边内容内边距 24 点；操作列表标题为 17 点 semibold、说明 14 点，内边距为 top/leading/trailing 0、bottom 20。操作列表的行样式与表头间距由 `sheetConfig` 管理。以下为 Alert 的样式示例，可在显示期间逐项修改并自动重新测量：

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

同一份样式还包含 Alert 使用的 `buttonFont`、`inputFont`、`buttonContentInsets` 和 `buttonLayout`。默认启用 Dynamic Type；传入基础 `UIFont` 即可，需要固定字号时将 `style.adjustsFontForContentSizeCategory` 设为 `false`。操作列表行字体使用 `sheetConfig.fontSize`，行高使用 `sheetConfig.cellHeight`。全部字段与默认值见 [字体、对齐与内容间距](Docs/UsageGuide.md#titles)。

标题仍位于内容顶部，`titleAlignment` 和 Alert 的 `buttonLayout` 便利属性直接读写同一份样式。整份替换 `configuration` 会同时替换样式；先选预设再设置定制项。直接设置 label 字体或对齐会在后续样式刷新时被覆盖。更新样式保留按钮标题、图标和输入内容及焦点。Alert 默认两个按钮左右等宽，取消在左、确认在右；操作列表使用分组表格行。内容栈不会重复叠加外部已避让的安全区。

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

需要玻璃遮罩时，先打开视觉遮罩；底部操作列表默认关闭遮罩。模糊和压暗程度独立设置：

```swift
popover.configuration.showsBackdrop = true
popover.configuration.appearance.backdropGlass = true
popover.configuration.appearance.backdropOpacity = 0 // 纯模糊；改为 0.12 可同时轻微压暗
```

`showsBackdrop = false` 同时隐藏压暗和模糊；系统开启降低透明度时不显示模糊。完整示例见 [玻璃遮罩](Docs/UsageGuide.md#backdrop-glass)。

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

直接打开 `Examples/BonePopoverDemo/BonePopoverDemo.xcodeproj`，选择 iPhone / iPad / Duo 模拟器运行。首页顶部常驻“外观 / 动画 / 遮罩 / 交互”四行控制项，中间是按用途分组的场景列表（每行带一句说明），底部常驻最近一次回调结果。共 23 个场景，含运行时切换风格、注入横/竖折叠区域、自定义 Alert 尺寸、长内容上限、竖排按钮、窄空间回退、自定义字体与间距、多窗口展示和三种 Toast。默认操作列表（场景 2）、即时调整字体/行高/间距（13）及玻璃遮罩（19）均使用 `BoneDrawerSheetView`；原分组选择场景 18 与单选、多选、拖动及固定高度滚动场景 20/21/22 归入“底部操作列表变体”。导航栏“标题对齐”菜单可选择预设默认、左、中、右，再打开确认框或操作列表预览。

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
