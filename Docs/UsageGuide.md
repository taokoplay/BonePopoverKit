# BonePopoverKit 使用说明

本文面向需要在 iOS 项目中接入、定制或扩展弹窗的开发者，对应当前工作区的 SDK 实现。首次接入可以先看第 1～3 节；迁移旧组件时同时阅读 [迁移说明](Migration.md)。

BonePopoverKit 是基于 UIKit 的 Swift Package，最低部署版本为 iOS 15。核心类 `BonePopoverView` 继承自 `UIViewController`，业务内容放在 `baseView` 中。样式、布局、动画和关闭交互分别配置，项目可以继续通过子类扩展。

当前交付为本地包，没有指定远程发布地址和版本 tag。旧项目未自动迁移，旧 `CLPopoverManager` 的队列等能力也不是本包的完整兼容接口。

## 目录

- [1. 环境与安装](#installation)
- [2. 快速开始与展示宿主](#quick-start)
- [3. 内置确认框、输入框和操作列表](#presets)
- [4. 字体、对齐与内容间距](#titles)
- [5. 外观与液态玻璃](#appearance)
- [6. 弹窗位置与尺寸](#layout)
- [7. 背景、外部点击和触摸穿透](#outside-touch)
- [8. 多方向滑动关闭](#swipe)
- [9. 动画](#animation)
- [10. 回调、关闭拦截与状态](#lifecycle)
- [11. 自定义内容与子类](#extension)
- [12. 键盘、长内容与 Duo 适配](#adaptation)
- [13. 配置速查](#reference)
- [14. Demo、迁移与常见问题](#faq)

<a id="installation"></a>

## 1. 环境与安装

| 项目 | 要求或行为 |
| --- | --- |
| 最低部署版本 | iOS 15.0 |
| 包名 / product / import 名称 | `BonePopoverKit` |
| Package tools version | 5.9 |
| 第三方依赖 | 无 |
| UI 框架 | UIKit |
| 调用线程 | UI 操作和配置在主线程 / `MainActor` 执行 |
| 原生液态玻璃 | 使用包含对应 API 的新 SDK 和编译器构建，运行于 iOS 26+ |
| Duo 折叠 / 摄像头保留区域 | 使用 Xcode 27.1 / Swift 6.4 构建，运行于 iOS 27.1+ |

Xcode 中选择 **File → Add Package Dependencies → Add Local**，选中 `BonePopoverKit` 目录，再给 App target 添加同名 library product。

其他 Swift Package 可以在依赖中使用 `.package(path: "../BonePopoverKit")`，并为需要调用 SDK 的 target 添加 `BonePopoverKit` product。路径按项目实际目录调整。

业务文件导入：

```swift
import UIKit
import BonePopoverKit
```

最低部署版本与构建 SDK 是两个概念：App 可以用新 Xcode 构建并保持 iOS 15 部署目标，运行时再按系统版本选择材质和适配能力。独立旧 Xcode 的编译回退路径尚未单独验证，具体执行范围见 [验证记录](Validation.md)。

<a id="quick-start"></a>

## 2. 快速开始与展示宿主

下面是一个完整的确认框示例：

```swift
@MainActor
func showSaveConfirmation(from presenter: UIViewController) {
    let alert = BoneAlertView(
        title: "保存更改",
        message: "将当前配置保存到项目？"
    ) {
        // 此时弹窗已移除，可继续保存或展示下一层界面。
        print("用户确认保存")
    }
    alert.configuration.appearance = .liquidGlass
    alert.titleAlignment = .center
    let shown = alert.show(from: presenter)
    if !shown {
        // 宿主尚未上屏、实例已展示等情况，按业务需要处理。
        print("本次未展示弹窗")
    }
}
```

从已显示的页面调用 `showSaveConfirmation(from: self)`。不要在页面尚未进入窗口时调用展示方法。

以下章节的短代码片段默认在主线程执行，其中 `presenter` 表示已在窗口中显示的 `UIViewController`；每段示例创建自己的弹窗实例。

| 展示方式 | 适用场景 |
| --- | --- |
| `show(from: presenter, animated: true)` | 页面内展示，覆盖 presenter.view |
| `show(over: sourceWindow, animated: true)` | 独立 Window，绑定明确的源窗口及所属 Scene |
| `show(in: scene, animated: true)` | 独立 Window，从明确的 Scene 选择有效业务宿主 |
| `show()` | 独立 Window，仅当恰好一个前台活动 Scene 时自动选择上下文 |
| `show(isNav: true)` | 兼容旧版独立窗口导航入口，自动选择唯一前台 Scene |

展示方法返回 `Bool`。同一实例已经展示、已有父控制器、正在被其他方式呈现、宿主未上屏或场景不明确时，不应继续假定展示成功。

**覆盖范围取决于入口。** `show(from:)` 添加到传入控制器的 view，覆盖导航栏/标签栏时传入对应容器控制器；Window 模式创建独立透明窗口。`show()` / `show(in:)` 从本包早期的页面内展示调整为独立 Window。层级、输入接管、导航、恢复与多 Scene 规则见 [独立 Window 模式](WindowPresentation.md)。窗口创建选项统一在 `configuration.window` 设置，本次展示保存快照；内容样式和交互配置仍可实时修改。

关闭使用 `hidden(_:)` 或 `dismissPopover(...)`，不要用系统的 `dismiss(animated:)` 代替：

```swift
let popover = BonePopoverView(configuration: .centerDialog)
popover.show(from: presenter)
popover.hidden {
    print("关闭动画完成，视图和控制器已移除")
}
```

上例展示后立即调用关闭，仅用于说明方法关系；正常业务应在按钮、任务完成或其他适当时机关闭。

<a id="presets"></a>

## 3. 内置确认框、输入框和操作列表

### 3.1 确认框

使用 `BoneAlertView(title:message:callback:)`。内置确认与取消按钮，确认回调在关闭并移除后执行；取消不会执行确认回调。

确认框和输入框默认使用**等宽横排**：在中文等从左到右的环境中，取消在左、确认在右，按钮间距 12 点。默认 `.automatic` 会在按钮标题放不下或启用辅助功能大字号时改为竖排；竖排保持确认在上、取消在下，避免文字截断。

```swift
let alert = BoneAlertView(title: "保存设置", message: "确认保存当前设置？") {}
alert.buttonLayout = .automatic // 默认；也可指定 .horizontal 或 .vertical
alert.show(from: presenter)
```

| `buttonLayout` | 行为 |
| --- | --- |
| `.automatic` | 默认横排，窄空间、长按钮文案或辅助功能大字号时自动竖排 |
| `.horizontal` | 明确要求左右等宽排列 |
| `.vertical` | 明确要求上下等宽排列，确认在上、取消在下 |

布局属性可在显示前或显示期间修改，会自动请求重新测量。若在显示期间直接修改按钮标题，调用 `invalidatePopoverLayout()` 重新检查文案所需宽度。`buttonLayout` 是 `configuration.contentStyle.buttonLayout` 的便利入口；整份替换 `configuration` 会同时替换它，先选配置预设再定制内容样式。操作列表仍保持各动作竖排。

字体、颜色、对齐和间距统一通过 `configuration.contentStyle` 定制，详见第 4 节。`titleLabel`、`messageLabel`、`confirmButton`、`cancelButton` 继续公开，便于修改文本、图标、辅助功能等 UIKit 属性。按钮使用 `UIButton.Configuration`，例如在加载视图后修改标题：

```swift
let alert = BoneAlertView(title: "退出编辑", message: "保存当前修改后退出？") {
    print("确认退出")
}
alert.loadViewIfNeeded()
alert.confirmButton.configuration?.title = "保存并退出"
alert.cancelButton.configuration?.title = "继续编辑"
alert.show(from: presenter)
```

### 3.2 单字段输入框

使用 `BoneAlertView(title:placeholder:callback:)`，回调返回输入文本。

```swift
let input = BoneAlertView(title: "项目名称", placeholder: "输入名称") { text in
    print("新名称：\(text)")
}
input.text = "我的项目"
input.keyboardType = .default
input.textField.isSecureTextEntry = false
input.titleAlignment = .left
input.show(from: presenter)
```

输入框显示后会自动尝试获取焦点，默认开启键盘避让。与确认框不同，**输入框默认禁止点外部关闭**，避免误触丢失输入；需要时可显式设置 `input.configuration.dismissOnBackdropTap = true`。

`textField` 是公开的 `UITextField`，可直接设置密码输入、自动填充、文本内容类型和其他 UIKit 属性。

### 3.3 操作列表

```swift
let sheet = BoneActionSheetView(
    title: "项目操作",
    message: "选择要执行的操作",
    actions: [
        PopoverAction("分享", image: UIImage(systemName: "square.and.arrow.up")) {
            print("执行分享")
        },
        PopoverAction("刷新状态", dismissesPopover: false) {
            print("刷新后继续保留弹窗")
        },
        PopoverAction("删除", role: .destructive) {
            print("执行删除业务")
        }
    ],
    cancelTitle: "返回"
)
sheet.titleAlignment = .center
sheet.show(from: presenter)
```

`PopoverAction` 默认先关闭，再执行 handler；`dismissesPopover: false` 则立即执行 handler 并保留弹窗。`.destructive` 只表示操作的视觉角色，不会自动增加二次确认或执行删除逻辑。

动作集合在初始化时提供。需要分组、多选、拖拽排序或 loading 流程时，使用自定义内容或业务子类；本版操作列表没有直接提供旧抽屉的全部接口。

<a id="titles"></a>

## 4. 字体、对齐与内容间距

确认框、输入框和操作列表共用 `PopoverContentStyle`，从 `configuration.contentStyle` 设置。它是值类型，可创建一份样式复用于多个弹窗。内置标题位于内容顶部，默认字体为 **`UIFont.boldSystemFont(ofSize: 18)`**，正文默认 **`UIFont.systemFont(ofSize: 17)`**。

```swift
let alert = BoneAlertView(title: "保存设置", message: "确认保存当前配置？") {}
var style = PopoverContentStyle()
style.titleFont = UIFont.boldSystemFont(ofSize: 18)
style.messageFont = UIFont.systemFont(ofSize: 16)
style.buttonFont = UIFont.systemFont(ofSize: 17, weight: .medium)
style.inputFont = UIFont.systemFont(ofSize: 17)
style.titleColor = .label
style.messageColor = .secondaryLabel
style.titleAlignment = .center
style.messageAlignment = .left
style.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
style.titleToContentSpacing = 12
style.contentToButtonsSpacing = 20
style.buttonSpacing = 12
style.buttonContentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
style.buttonLayout = .automatic
style.adjustsFontForContentSizeCategory = true
alert.configuration.contentStyle = style
alert.show(from: presenter)

// 显示期间也可逐项修改，控件和弹窗尺寸会自动刷新。
alert.configuration.contentStyle.messageFont = UIFont.systemFont(ofSize: 18)
alert.configuration.contentStyle.contentToButtonsSpacing = 24
```

| 样式属性 | 默认值 | 含义 |
| --- | --- | --- |
| `titleFont` | `.boldSystemFont(ofSize: 18)` | 标题基础字体，接受任意 `UIFont` |
| `messageFont` | `.systemFont(ofSize: 17)` | 正文基础字体，接受任意 `UIFont` |
| `buttonFont` / `inputFont` | `.systemFont(ofSize: 17)` | 按钮 / 输入文本基础字体 |
| `titleColor` / `messageColor` | `.label` / `.secondaryLabel` | 标题 / 正文颜色 |
| `titleAlignment` / `messageAlignment` | `.left` / `.natural` | 标题 / 正文分别对齐 |
| `contentInsets` | 四边各 24 点 | 内容到面板内容边缘的内部留白 |
| `titleToContentSpacing` | 14 点 | 标题到正文或输入框 |
| `contentToButtonsSpacing` | 14 点 | 正文或输入框到按钮；无正文的操作列表为标题到首个按钮 |
| `buttonSpacing` | 12 点 | 横排 / 竖排按钮之间，以及操作列表动作之间 |
| `buttonContentInsets` | 上下 12、左右 16 点 | 按钮内部文字和图标周围的留白 |
| `buttonLayout` | `.automatic` | 仅控制 Alert；操作列表始终竖排 |
| `adjustsFontForContentSizeCategory` | `true` | 使用 `UIFontMetrics` 随系统字号缩放 |

传入基础字体即可，无需预先调用 `scaledFont`。默认系统字号下标题为 18 点粗体；开启 Dynamic Type 后会随系统文字大小变化。要求固定字号时将 `adjustsFontForContentSizeCategory` 设为 `false`。Alert 的自动按钮排列会综合实际字体、内部留白和按钮间距判断宽度；辅助功能字号下自动使用竖排，关闭字体缩放也保留这一排列策略。按钮最小高度 44 点，输入框最小高度 48 点；大字体或更大的按钮内边距可继续撑高。

`BoneAlertView.titleAlignment`、`BoneActionSheetView.titleAlignment` 以及 Alert 的 `buttonLayout` 都直接读写同一份 `contentStyle`。标题支持 `.left`、`.center`、`.right`，不会改变正文的独立对齐。样式是内置控件的统一来源，直接修改 label 的字体、颜色或对齐，会在下一次样式刷新（包括外观配置或系统字号变化）时被覆盖。按钮标题、图标、角色及已有输入内容和焦点会保留。

整份赋值 `configuration` 会同时替换内容样式；仅修改 `configuration.appearance` 或 `layout` 则保留当前 `contentStyle`。同一份样式赋给多个弹窗后，各自保存副本，后续修改其中一个不会影响其他弹窗。自定义内容可以覆盖 `applyContentStyle()` 将样式应用到业务控件，并在构建完控件后主动调用一次；SDK 在配置和系统字号变化时调用该钩子，并请求宿主重新布局。

`contentStyle` 负责内部字体和间距；外部留白、最大尺寸属于 `layout`，材质、圆角和阴影属于 `appearance`。间距负值按 0 处理，非有限值回退为对应默认值。内容栈不重复叠加外部已经避让的安全区。底部弹窗的抓手位于内容上方，因此标题到整个面板顶部的距离还会包含抓手区域。

<a id="appearance"></a>

## 5. 外观与液态玻璃

### 5.1 选择材质

| 外观 | iOS 26+ 且构建支持原生玻璃 | 较低系统或编译回退路径 |
| --- | --- | --- |
| `PopoverAppearance()` / `.material = .automatic` | 原生液态玻璃 | 纯色表面 |
| `.classic` | 纯色表面，圆角默认 16 点 | 相同 |
| `.frosted` | 系统 material 模糊 | 相同 |
| `.liquidGlass` | 原生 `UIGlassEffect` | `.systemMaterial` 模糊 |
| `.material = .solid` | 自定义纯色 | 相同 |
| `.material = .blur(style)` | 指定 `UIBlurEffect.Style` | 相同 |

```swift
let popover = BonePopoverView(configuration: .bottomSheet)
var appearance = PopoverAppearance.liquidGlass
appearance.tintColor = .systemIndigo
appearance.cornerRadius = 28
appearance.borderWidth = 0
appearance.backdropOpacity = 0.25
popover.configuration.appearance = appearance
popover.show(from: presenter)
```

`backgroundColor` 用于纯色表面和降低透明度时的回退；它不会给原生玻璃加一层实色填充。玻璃染色使用 `tintColor`，在模糊回退路径上不保证相同染色效果。

### 5.2 玻璃边缘和阴影

原生玻璃直接通过效果视图自身的 `cornerConfiguration` 定义圆角。文字和按钮位于独立前景层，避免材质合成影响清晰度。

玻璃默认使用系统边缘和阴影，不额外叠加普通卡片阴影。确实需要额外阴影时，设置 `appearance.addsShadowToLiquidGlass = true`，再调整 `shadowColor`、`shadowOpacity`、`shadowRadius` 和 `shadowOffset`。经典、模糊和旧系统回退使用这些可配置阴影。

保持业务内容和 `baseView` 背景透明，避免不透明业务底色盖住玻璃；对玻璃祖先再添加遮罩或裁切，也可能切掉边缘光影。

### 5.3 完全替换背景

```swift
let popover = BonePopoverView(configuration: .centerDialog)
let background = UIView()
background.backgroundColor = .systemTeal
popover.customBackgroundView = background
popover.show(from: presenter)
```

`customBackgroundView` 会替换 SDK 的材质背景，并按面板大小布局。设回 `nil` 后恢复 `configuration.appearance` 指定的材质。

系统开启“降低透明度”时，内置材质默认回退为纯色；自定义背景由应用负责无障碍可读性。SDK 还支持深浅色系统颜色和动态字号。

<a id="layout"></a>

## 6. 弹窗位置与尺寸

### 6.1 使用布局预设

| `PopoverConfiguration` 预设 | 位置 | 最大宽度 | 默认动画 | 默认拖拽 |
| --- | --- | --- | --- | --- |
| `.bottomSheet` | 底部 | 560 点 | 底部滑入 | 开，自动向下 |
| `.centerDialog` | 居中 | 420 点 | 缩放 | 关 |
| `.topBanner` | 顶部 | 560 点 | 顶部滑入 | 开，自动向上 |
| `.sidePanel` | trailing 侧，高度填满 | 400 点 | trailing 侧滑入 | 开，自动向外 |

`.bottomSheet` 默认显示抓手。`.topBanner` 的背景遮罩透明度默认是 0.12，不会自动消失；其余预设默认 0.32。

`BonePopoverView` 无配置初始化时默认使用居中预设；`BonePopoverView(contentView:)` 默认使用底部预设。直接创建 `PopoverConfiguration()` 的默认布局是底部。

整份赋值 `popover.configuration = .bottomSheet` 会重置此前修改的整份配置。建议先选择预设，再修改样式和交互。

`BoneAlertView` 的确认框与输入框在居中预设基础上，额外采用左右各 **32 点外部间距**，以及 **420 × 600 点最大尺寸**。通用 `.centerDialog` 和操作列表的原始默认值不受影响。

### 6.2 调整宽高

```swift
let popover = BonePopoverView(configuration: .bottomSheet)
popover.configuration.layout.width = .fill
popover.configuration.layout.height = .fraction(0.7)
popover.configuration.layout.maximumWidth = 600
popover.configuration.layout.maximumHeight = 700
popover.configuration.layout.margins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
popover.show(from: presenter)
```

| 尺寸类型 | 含义 |
| --- | --- |
| `.content` | 使用测量结果，适合 Auto Layout 内容或自定义测量 |
| `.fixed(points)` | 请求固定点数，仍受实际可用区域和最大尺寸约束 |
| `.fraction(value)` | 使用选定可用区域尺寸的比例，比例限制在 0～1 |
| `.fill` | 填满选定可用区域，仍受最大尺寸约束 |

`.content` 默认主要用于测量内容高度。若需要特定内容宽度，可提供合适的 `preferredContentSize`，或覆盖 `preferredPopoverSize(fitting:)`；默认测量实现会优先使用传入的可用宽度。

布局位置还可选择 `.leading` / `.trailing`。这两个位置随 RTL 语义变化；滑动方向中的 `.left` / `.right` 则始终是物理方向。

### 6.3 Alert 外部间距与 iPad 最大尺寸

```swift
let alert = BoneAlertView(title: "项目设置", message: "确认使用当前设置？") {}
alert.horizontalMargin = 40
alert.maximumSize = CGSize(width: 480, height: 560)
alert.show(from: presenter)
```

| Alert 属性 | 默认值 | 作用 |
| --- | --- | --- |
| `horizontalMargin` | 32 点 | 同时设置左右最小外部间距，对应 `configuration.layout.margins.left/right` |
| `maximumSize` | 420 × 600 点 | 整个面板的最大宽高，对应 `configuration.layout.maximumWidth/maximumHeight` |

这两个属性可在显示前或显示期间修改。外部间距从安全区及折叠区域之外的可用矩形边缘计算，与标题、正文和按钮的 24 点内部边距不同。需要左右不同的间距时，直接修改 `layout.margins`；此时 `horizontalMargin` 读取左侧值。

最大尺寸在 iPad、Duo 和其他窗口尺寸下都生效，不通过机型名称或 `regular` 尺寸类别猜测设备。面板实际宽高取内容请求、最大尺寸和当前可用空间的限制：iPad 全屏不会无限放大，窄分屏、键盘及折叠区域较小时仍会继续缩小；超高内容默认可滚动到操作按钮。

先选择配置预设，再设置 `horizontalMargin` 和 `maximumSize`。之后整份赋值 `alert.configuration = .centerDialog` 等预设，会替换它们对应的底层配置值。请传入非负有限值；负值按 0 处理，非有限值会被忽略。

<a id="outside-touch"></a>

## 7. 背景、外部点击和触摸穿透

这是三组独立配置：

| 配置 | 默认值 | 控制内容 |
| --- | --- | --- |
| `showsBackdrop` | `true` | 是否显示外部背景遮罩 |
| `appearance.backdropColor` / `backdropOpacity` | 黑色 / 0.32 | 遮罩颜色和视觉透明度，预设可覆盖 |
| `dismissOnBackdropTap` | `true` | 不穿透时，点击弹窗外部是否请求关闭；输入框预设为 `false` |
| `allowsEventPenetration` | `false` | 外部触摸是否传给底层页面 |
| `autoHideWhenPenetrated` | `false` | 穿透时，真实外部点击结束后是否同时请求关闭 |

### 7.1 常用组合

以下结果假设关闭请求未被 `shouldDismiss` 拦截。

| 想要的行为 | `showsBackdrop` | `allowsEventPenetration` | `dismissOnBackdropTap` | `autoHideWhenPenetrated` | 底层收到点击 |
| --- | --- | --- | --- | --- | --- |
| 有遮罩，点外部关闭 | `true` | `false` | `true` | 不参与 | 否 |
| 无遮罩，点外部关闭 | `false` | `false` | `true` | 不参与 | 否 |
| 点外部不关闭，也不操作底层 | 任意 | `false` | `false` | 不参与 | 否 |
| 点击传给底层，弹窗保留 | 任意 | `true` | 不参与 | `false` | 是 |
| 点击传给底层，同时关闭弹窗 | 任意 | `true` | 不参与 | `true` | 是 |

**透明背景不等于触摸穿透。** `showsBackdrop = false` 或 `backdropOpacity = 0` 只改变视觉；不穿透时仍有透明点击层，可以关闭弹窗或拦截外部操作。

### 7.2 隐藏背景但允许点外部关闭

```swift
let popover = BonePopoverView(configuration: .centerDialog)
popover.configuration.showsBackdrop = false
popover.configuration.dismissOnBackdropTap = true
popover.configuration.allowsEventPenetration = false
popover.show(from: presenter)
```

### 7.3 穿透并关闭

```swift
let popover = BonePopoverView(configuration: .centerDialog)
popover.configuration.showsBackdrop = false
popover.configuration.allowsEventPenetration = true
popover.configuration.autoHideWhenPenetrated = true
popover.show(from: presenter)
```

穿透模式由 `autoHideWhenPenetrated` 决定是否自动关闭，`dismissOnBackdropTap` 不参与这一判断。若关闭被拦截，底层仍收到该次点击。

穿透只影响弹窗外部、并且位于展示容器范围内的触摸。穿透自动关闭针对点击结束，不表示任意拖动、滚动开始都会关闭。命中测试查询本身不会触发关闭。

开启穿透时，SDK 不再把浮层作为辅助功能模态区域，底层页面仍可参与辅助功能导航。

<a id="swipe"></a>

## 8. 多方向滑动关闭

### 8.1 开启居中弹窗四向拖拽

```swift
let popover = BonePopoverView(configuration: .centerDialog)
popover.configuration.allowsDragToDismiss = true
popover.configuration.allowedSwipeDirections = .all
popover.configuration.swipeThreshold = 100
popover.show(from: presenter)
```

方向类型为 `PopoverSwipeDirection`，支持：

| 取值 | 行为 |
| --- | --- |
| `.left` / `.right` / `.up` / `.down` | 单个物理方向 |
| `[.left, .down]` 等组合 | 只允许指定方向 |
| `.all` | 四向 |
| `.horizontal` / `.vertical` | 左右 / 上下 |
| `.none` | 不允许任何方向 |
| `.automatic` | 按位置向外：底部向下、顶部向上、两侧向外；居中开启拖拽后为四向 |

`allowsDragToDismiss = false` 是总开关，优先于方向配置。居中预设默认关，因此只改成 `.all` 不足以开启居中拖拽。

### 8.2 阈值、取消和滚动协调

`swipeThreshold` 默认 100 点。慢速拖动要超过该距离；快速滑动使用下面的投影距离判断：

```text
投影距离 = 当前沿关闭方向的位移 + 松手时沿该方向的速度 × 0.15 秒
```

这意味着短距离快滑也可能关闭。阈值是点数，不是百分比。方向在拖动开始时锁定；取消、位移不足、明显反向收回或关闭被拦截时，弹窗回弹。

拖动标题、说明或其他非控件区域。按钮、输入框等控件保留自身触摸行为。触摸从滚动视图开始时，内容在相应方向还能滚动，就优先滚动；达到对应边界后才允许拖动弹窗。

非穿透弹窗显示期间，SDK 暂停宿主导航控制器的边缘返回，以及 iOS 26 起的整页返回手势，避免未允许的右滑反而返回底层页面。最后一个相关弹窗关闭后恢复原启用状态。穿透模式保留底层导航行为。

<a id="animation"></a>

## 9. 动画

| 动画 | 默认参数 | 适用场景 |
| --- | --- | --- |
| `.slide(edge)` | 0.32 秒、阻尼比 1 | 底部、顶部、侧边面板 |
| `.fade` | 0.2 秒 | 淡入淡出 |
| `.scale` | 0.25 秒，隐藏比例 0.92 | 居中确认框 |
| `.spring` | 0.4 秒、阻尼比 0.82 | 需要轻微弹性的展示 |
| `.none` | 0 秒 | 立即展示与关闭 |

```swift
let popover = BonePopoverView(configuration: .bottomSheet)
popover.configuration.animation = .slide(.bottom, duration: 0.35, dampingRatio: 0.9)
popover.show(from: presenter)
```

自定义动画提供隐藏端点；显示端点是单位变换和透明度 1：

```swift
let popover = BonePopoverView(configuration: .centerDialog)
popover.configuration.animation = PopoverAnimation(duration: 0.3, dampingRatio: 0.9) { _, _, _ in
    PopoverVisualState(
        transform: CGAffineTransform(translationX: 0, y: 32).scaledBy(x: 0.96, y: 0.96),
        opacity: 0
    )
}
popover.show(from: presenter)
```

程序关闭按配置的隐藏路径退出；滑动关闭沿锁定的手指方向退出，不改写原入场配置。出现动画可以被关闭打断。

默认尊重系统“减弱动态效果”，使用较温和的淡入淡出。`respectsReduceMotion` 可以控制该行为；通常保留默认值即可。

<a id="lifecycle"></a>

## 10. 回调、关闭拦截与状态

| API | 时机或含义 |
| --- | --- |
| `onDidShow` | 展示完成后；被中途关闭的展示不会正常进入此回调 |
| `notificationHidden(type:)` | 可覆盖的关闭原因钩子，实际移除后调用 |
| `notificationDismissComplete` | 每次实际关闭完成后调用 |
| `hidden(completion)` | 直接请求关闭，移除完成后执行 completion |
| `dismissPopover(animated:reason:completion:)` | 可指定动画和原因的直接关闭 |
| `presentationState` | `hidden`、`presenting`、`presented`、`dismissing` |
| `isPresented` | 只要不在 `hidden`，就为 `true`，包括关闭动画期间 |

重复关闭请求的 completion 会合并到同一次实际关闭后，各执行一次；实际关闭通知只发一次。实例关闭后可再次使用。

### 10.1 关闭原因

| `PopoverDismissReason` | 来源 |
| --- | --- |
| `.normal` | 程序关闭，内置确认 / 取消等直接关闭 |
| `.penetration` | 外部点击关闭，包括穿透点击后的自动关闭 |
| `.slide` | 滑动关闭 |
| `.accessibility` | 辅助功能退出手势 |
| `.hostRemoved` | 展示宿主离开窗口后自动清理 |

`CLPopoverDismissType` 是兼容 typealias，指向上述枚举。旧代码若穷举关闭原因，需要补充新分支。

### 10.2 拦截关闭的范围

```swift
let popover = BonePopoverView(configuration: .centerDialog)
popover.shouldDismiss = { _ in
    // 拒绝外部点击、滑动和辅助功能退出等关闭请求。
    false
}
popover.show(from: presenter)
// 任务结束或业务决定退出时，仍可直接调用 popover.hidden()。
```

`shouldDismiss` 处理外部点击、穿透自动关闭、滑动和辅助功能退出请求。**它不会阻止直接调用 `hidden()` / `dismissPopover()`，也不会阻止内置确认、取消和默认关闭动作的按钮流程。** 宿主移除时的清理也不依赖该拦截。

需要“工作中连确认 / 取消都不可关闭”的业务，应同时禁用或替换相应按钮动作，并在适当时机恢复。不能只设置 `shouldDismiss = { _ in false }` 就假定所有路径都被锁住。

持有弹窗的业务对象在给它设置闭包时，通常应使用 `[weak self]` 避免循环持有。清理请求、播放器或网页任务可放到关闭钩子里，不要只依赖用户点击某个按钮。

<a id="extension"></a>

## 11. 自定义内容与子类

### 11.1 任意 Auto Layout 内容

```swift
let title = UILabel()
title.text = "阅读设置"
title.font = .preferredFont(forTextStyle: .headline)
title.adjustsFontForContentSizeCategory = true
let message = UILabel()
message.text = "这里可以继续添加应用自己的设置控件。"
message.numberOfLines = 0
message.font = .preferredFont(forTextStyle: .body)
message.adjustsFontForContentSizeCategory = true
let stack = UIStackView(arrangedSubviews: [title, message])
stack.axis = .vertical
stack.spacing = 12
stack.isLayoutMarginsRelativeArrangement = true
stack.insetsLayoutMarginsFromSafeArea = false
stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
let popover = BonePopoverView(contentView: stack, configuration: .bottomSheet)
popover.show(from: presenter)
```

`setContentView(_:)` 会将内容约束到 `baseView` 四边，并移除此前通过该方法设置的内容。内容必须具备可测量的完整约束；不要把缺少高度信息的空容器当作可自动测量内容。默认测量无法取得有效高度时使用 300 点回退。

内容大小改变后调用 `invalidatePopoverLayout()`。也可提供 `preferredContentSize`，或覆盖下面的测量方法。

### 11.2 手动布局子类

```swift
@MainActor
final class ReaderSettingsPopover: BonePopoverView {
    private let heading = UILabel()
    private let closeButton = UIButton(type: .system)

    init() {
        super.init(nibName: nil, bundle: nil)
        configuration = .bottomSheet
        configuration.appearance = .classic
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "阅读设置"
        heading.font = .preferredFont(forTextStyle: .headline)
        heading.adjustsFontForContentSizeCategory = true
        closeButton.setTitle("完成", for: .normal)
        closeButton.addAction(UIAction { [weak self] _ in self?.hidden() }, for: .touchUpInside)
        baseView.addSubview(heading)
        baseView.addSubview(closeButton)
    }

    override func preferredPopoverSize(fitting availableSize: CGSize) -> CGSize {
        CGSize(width: availableSize.width, height: 320)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = max(0, baseView.bounds.width - 48)
        heading.frame = CGRect(x: 24, y: 24, width: width, height: 44)
        closeButton.frame = CGRect(x: 24, y: 252, width: width, height: 44)
    }

    override func notificationHidden(type: CLPopoverDismissType) {
        // 在此释放业务资源或结束任务。
    }
}
```

业务层只布局 `baseView` 内部控件。弹窗本身的位置、变换和动画交给 SDK，不要再修改整屏 `view.frame.origin.y` 或使用 `UIScreen.main.bounds` 定位弹窗。

复杂滚动内容还可覆盖 `shouldBeginSwipeToDismiss(_:)` 和 `shouldRecognizeSwipeToDismissSimultaneously(with:)`。前者是 SDK 自带方向与滚动检查后的附加业务限制，不会放开被配置禁用的方向。

<a id="adaptation"></a>

## 12. 键盘、长内容与 Duo 适配

### 键盘与长内容

`configuration.layout.avoidsKeyboard` 默认为 `true`。SDK 将键盘区域纳入可用空间计算，并尝试让弹窗内的输入焦点保持可见。`isShowKeyboard` 和 `keyboardFrameEnd` 提供只读兼容状态，后者使用屏幕坐标，业务通常无需再次按键盘高度上移内容。

`configuration.scrollsOverflow` 默认为 `true`。内容高于可用空间时，外层允许滚动；包含自有 `UITableView`、`UICollectionView` 或网页滚动区域时，可以关闭外层溢出滚动，并由业务确定合理高度和内部滚动规则。

### Duo 与尺寸变化

SDK 每次布局使用当前展示容器的尺寸、安全区、键盘和活动保留区域，不按机型名称或启动时缓存的屏幕尺寸判断。

iOS 27.1 上通过系统 `.division` / `.occlusion` 查询避开活动折叠和摄像头区域，区域 frame 已包含系统边距。默认在面积相近的区域中偏向 trailing / bottom，也可选择：

```swift
let popover = BonePopoverView(configuration: .centerDialog)
popover.configuration.layout.regionPreference = .trailing
popover.configuration.layout.maximumWidth = 420
popover.show(from: presenter)
```

区域偏好还支持 `.largest`、`.leading`、`.top`、`.bottom`、`.automatic`。`layout.anchorPoint` 可关联触发位置，坐标必须与 SDK 展示宿主视图一致，不是屏幕全局坐标。

自定义显示环境或测试可以通过 `reservedRegionProvider` 覆盖系统区域查询。下面仅演示注入一条竖向区域，不是设备状态检测：

```swift
let popover = BonePopoverView(configuration: .centerDialog)
popover.reservedRegionProvider = { host in
    [CGRect(x: host.bounds.midX - 12, y: 0, width: 24, height: host.bounds.height)]
}
popover.show(from: presenter)
```

`layout.avoidsReservedRegions = false` 可禁用区域避让。默认不要关闭；SDK 能调整面板位置和大小，但不会自动修复业务内容内部的硬编码宽度。

App 也需要使用支持该设备的新 SDK 构建。当前已有 Duo 模拟器与注入折叠几何验证，未完成实体 Duo 全部姿态、摄像头状态和分屏组合的验收。

<a id="reference"></a>

## 13. 配置速查

| 需要调整的内容 | API | 默认值或注意事项 |
| --- | --- | --- |
| 整体配置 | `popover.configuration` | `BonePopoverView` 默认居中；整份赋值会重置先前修改 |
| 独立窗口 | `configuration.window` | level 默认 `.alert - 1`，自动叠加、接管并恢复 key、普通容器；创建时快照，见 [窗口配置](WindowPresentation.md#窗口配置) |
| 内置内容样式 | `configuration.contentStyle` | 确认 / 输入 / 操作列表共用，详见第 4 节 |
| 标题 / 正文字体 | `contentStyle.titleFont` / `messageFont` | 18 点粗体 / 17 点常规 |
| 标题 / 正文对齐 | `contentStyle.titleAlignment` / `messageAlignment` | `.left` / `.natural` |
| 内容内边距 | `contentStyle.contentInsets` | 四边各 24 点 |
| 标题 / 内容 / 按钮间距 | `titleToContentSpacing` / `contentToButtonsSpacing` / `buttonSpacing` | 14 / 14 / 12 点，均在 `contentStyle` 中 |
| 动态字号 | `contentStyle.adjustsFontForContentSizeCategory` | `true`；固定字号设为 `false` |
| 材质 | `appearance.material` | `.automatic` |
| 圆角 | `appearance.cornerRadius` | 24；经典预设为 16 |
| 抓手 | `appearance.showsGrabber` | `false`；底部预设为 `true` |
| 边框 | `appearance.borderColor` / `borderWidth` | `.separator` / 0 |
| 自定义阴影 | `shadowColor` / `shadowOpacity` / `shadowRadius` / `shadowOffset` | 黑色 / 0.16 / 24 / `(0, 8)` |
| 玻璃额外阴影 | `appearance.addsShadowToLiquidGlass` | `false` |
| 自定义背景 | `popover.customBackgroundView` | `nil`；设置后替换材质 |
| 位置 | `layout.placement` | `.bottom`；居中预设为 `.center` |
| 宽高 | `layout.width` / `height` | `.fill` / `.content` |
| 最大宽高 | `layout.maximumWidth` / `maximumHeight` | 560 / 不额外设有限上限，仍受可用空间约束 |
| 外部间距 | `layout.margins` | 通用配置四边各 12 点；`BoneAlertView` 左右为 32 点 |
| Alert 左右外部间距 | `alert.horizontalMargin` | 32 点，可运行时设置 |
| Alert 最大尺寸 | `alert.maximumSize` | 420 × 600 点，可在 iPad / Duo 等场景设置，实际尺寸仍受可用空间限制 |
| Alert 按钮排列 | `alert.buttonLayout` | `.automatic`，默认左右等宽，必要时自动竖排；可指定 `.horizontal` / `.vertical` |
| 区域选择 | `layout.regionPreference` / `anchorPoint` | `.automatic` / `nil` |
| 键盘 / 保留区域避让 | `layout.avoidsKeyboard` / `avoidsReservedRegions` | 均为 `true` |
| 长内容滚动 | `scrollsOverflow` | `true` |
| 背景 / 外部点击 / 穿透 | 第 7 节配置表 | 可独立设置 |
| 滑动方向 / 距离 | `allowedSwipeDirections` / `swipeThreshold` | `.automatic` / 100 点 |
| 辅助功能适配 | `respectsReduceMotion` / `respectsReduceTransparency` | 均为 `true` |
| 旧弹出类型 | `popover.popupType` | `.alert` / `.sheet` / `.fadeIn`；映射位置或动画，不替代完整配置 |
| 实例标识 | `popover.key` | 每个实例的稳定 UUID 字符串 |

此表中的布局原始默认值来自 `PopoverConfiguration()`；使用预设时以第 6 节和源代码的预设覆盖值为准。

<a id="faq"></a>

## 14. Demo、迁移与常见问题

### 14.1 Demo 怎么运行

打开 `Examples/BonePopoverDemo/BonePopoverDemo.xcodeproj`，选择可用 iPhone / iPad / Duo 目标运行。目录是相对于包根目录。

- 主页面：先选外观、动画，再进入确认、输入、操作列表等场景。
- “标题对齐”：选择左、中、右对齐后打开内置弹窗。
- “自定义字体与间距”：预览统一样式的字体、内边距与段落/按钮间距。
- “即时调整内容样式”：在弹窗内点击按钮，切换默认样式与大字号、宽间距，再切回。
- “关闭交互”：设置背景、外部点击、穿透、方向与 50 / 100 / 200 点阈值。
- “交互方案”：快速选择透明外部关闭、穿透不关闭、穿透并关闭、四向滑动、仅左滑和高阈值。
- “底层点击次数”：确认同一次穿透点击确实传给了底层页面。
- “多窗口展示”：切换双业务 Window，验证自动/固定层级、乱序关闭、输入与 key 恢复、穿透计数、导航及第二 Scene；测试启动参数为 `--window-demo`。
- 注入折叠场景：验证几何避让，不等同于硬件姿态检测。

项目使用 XcodeGen 配置，可在包根目录重新生成工程：

```sh
xcodegen generate --spec Examples/BonePopoverDemo/project.yml
```

### 14.2 常见问题

| 问题 | 先检查什么 |
| --- | --- |
| 弹窗没有出现 | 检查 `show` 返回值、宿主是否进入窗口、同一实例是否已展示；多 scene 使用显式宿主 |
| 居中弹窗不能滑动 | 同时设置 `allowsDragToDismiss = true` 和所需 `allowedSwipeDirections` |
| 背景透明但底层点不了 | 透明只控制视觉；需要操作底层时开启 `allowsEventPenetration` |
| 开穿透后不自动关闭 | 检查 `autoHideWhenPenetrated`，不要只改 `dismissOnBackdropTap` |
| 设置了拦截但确认 / 取消仍关闭 | 内置按钮使用直接关闭，不走 `shouldDismiss`，见第 10 节 |
| 玻璃像普通模糊 | 核对构建 SDK、运行系统、降低透明度设置、业务背景是否不透明及祖先是否裁切 |
| 内容顶部或侧边留白异常 | 自定义内容是否重复应用安全区到 layout margins；用局部 bounds 布局 |
| 窄屏、折叠后按钮超出 | 检查业务固定宽度，使用 `baseView.bounds`、可用尺寸或 Auto Layout |
| 字体、颜色或对齐改了又恢复 | 用 `configuration.contentStyle` 设置；直接改 label 会被后续样式刷新覆盖，整份替换 `configuration` 也会重置样式 |
| `swift test` 提示找不到 UIKit | macOS 目标无法运行 UIKit 测试，使用 iOS destination 的 `xcodebuild test` |

### 14.3 旧组件如何接入

先看 [迁移说明](Migration.md)，再逐屏迁移。保留的常用名称包括 `BonePopoverView`、`baseView`、`popupType`、`show()`、`hidden()` 和关闭通知，但旧 `.config` 要映射为 `.configuration`。

尤其注意：旧项目的 `BoneAlertView` 与 ParsingBook 的同名类含义不同；旧管理器排队、插队、替换、唯一模式、优先级，以及旧抽屉的多选和排序接口，不会因添加本包就自动迁移。窗口级别已映射为 `configuration.window.level`，导航入口与 Scene 规则见 [独立 Window 模式](WindowPresentation.md)。

### 14.4 已验证到什么程度

已完成 iOS 15 部署目标 / Swift 6 严格类型检查、24 组手册与窗口示例编译、59 项核心回归，以及 iPad 的 22 项窗口托管测试。窗口测试覆盖创建快照、固定/自动层级、key 与输入恢复、穿透观察器清理、回调重入、实际对象释放、导航栈及真实双 Scene 隔离和销毁；独立 Window 内的窄宿主、横竖保留区域、键盘通知与材质切换也在 iPhone / iPad / Duo 通过定向验证。手机和平板实际点击、各次失败与复测，以及新版 Demo 安装启动结果统一见 [验证记录](Validation.md)。

这些记录不表示所有系统版本和实体设备都完成验收。Duo 模拟器支持第二 Scene 激活，但系统拒绝主动销毁，相关阶段明确跳过，不能代替 iPad 的销毁隔离结果。iOS 15 没有实际运行验证；实体 Duo 全姿态、全部 iPadOS 窄分屏组合和完整辅助功能人工验收尚未完成；此前 iOS 27.1 连续输入后点击问题仍独立记录。原组件分布见 [项目清单](Inventory.md)。
