# BonePopoverKit 使用说明

本文介绍 BonePopoverKit 的安装、内置弹窗、自定义内容与参数配置。首次接入可以先看第 1～3 节，完整配置字段见第 13 节。

BonePopoverKit 是基于 UIKit 的独立弹窗组件，通过 Swift Package 集成，最低部署版本为 iOS 15，无第三方依赖。提供可继承的 `BonePopoverView` 与内容容器 `baseView`，支持页面内展示、独立 Window 和导航。

参数表统一采用“字段、名称、默认值、说明”，每个字段单独一行。样式、材质外观、布局、动画、窗口与交互分别配置，默认值和生效范围在对应表格中说明。

## 目录

- [1. 环境与安装](#installation)
- [2. 快速开始与展示宿主](#quick-start)
- [3. 内置确认框、输入框、操作列表与 Toast](#presets)
  - [3.4 Toast 提示](#toast)
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

Xcode 中选择 **File → Add Package Dependencies**，输入 `https://github.com/taokoplay/BonePopoverKit.git`，选择 `main` 分支，再给 App target 添加 `BonePopoverKit` library product。

其他 Swift Package 可使用 `.package(url: "https://github.com/taokoplay/BonePopoverKit.git", branch: "main")`，并为调用组件的 target 添加同名 product。本地开发可用 Add Local 选择组件目录，或使用 `.package(path: "../BonePopoverKit")`。

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
| `show(isNav: true)` | 自动选择唯一前台 Scene，创建带 UIKit 导航容器的独立 Window |

展示方法返回 `Bool`。同一实例已经展示、已有父控制器、正在被其他方式呈现、宿主未上屏或场景不明确时，不应继续假定展示成功。

**覆盖范围取决于入口。** `show(from:)` 添加到传入控制器的 view，覆盖导航栏/标签栏时传入对应容器控制器；其余入口创建独立透明窗口。层级、输入接管、导航、恢复与多 Scene 规则见 [独立 Window 模式](WindowPresentation.md)。窗口创建选项统一在 `configuration.window` 设置，本次展示保存快照；内容样式和交互配置可在显示期间修改。

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

## 3. 内置确认框、输入框、操作列表与 Toast

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

也可以先建面板再逐个添加动作，`addButton` / `addAction` 返回对应的 `UIButton`，方便继续设置辅助功能标识等属性：

```swift
let sheet = BoneActionSheetView(title: "项目操作", message: "选择要执行的操作")
let share = sheet.addButton("分享", image: UIImage(systemName: "square.and.arrow.up")) {
    print("执行分享")
}
share.accessibilityIdentifier = "sheet-share"
sheet.addButton("刷新状态", dismissesPopover: false) { print("刷新后继续保留弹窗") }
sheet.addButton("删除", role: .destructive) { print("执行删除业务") }
sheet.cancelTitle = "返回"
sheet.show(from: presenter)
```

`addAction` 接受完整 `PopoverAction`；两种写法可以混用，新按钮始终排在取消按钮之上，添加后立即重新测量，已展示时也会即时刷新高度。

操作列表默认在标题左侧显示向下箭头关闭按钮（阅读器默认头部样式，40 × 40 点圆形命中区，图标颜色跟随 `contentStyle.titleColor`），点击关闭弹窗；设置 `sheet.showsCloseButton = false` 可隐藏，标题随即回到内容左边距。`closeButton` 可直接访问，用于定制图标或辅助功能属性。

文案可运行期替换且默认不变：`sheet.cancelTitle = "Dismiss"`，未设置时回退初始化参数，再回退“取消”；关闭按钮辅助功能标签走 `sheet.closeAccessibilityLabel`（默认“关闭”）。遮罩标签是 `popover.backdropAccessibilityLabel`，Toast 类型朗读描述是 `toast.typeDescriptions`，见第 7 节。

`PopoverAction` 的字段如下，默认值来自其初始化参数：

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `title` | 动作标题 | 初始化时必传 | 按钮显示的文字。 |
| `image` | 动作图标 | `nil` | 按钮的可选 UIImage 图标。 |
| `role` | 视觉角色 | `.normal` | normal 使用普通颜色，destructive 使用红色强调。 |
| `dismissesPopover` | 执行前关闭 | `true` | true 时先关闭再执行 handler；false 时立即执行并保留弹窗。 |
| `handler` | 动作闭包 | 空闭包 `{}` | 点击时执行的业务逻辑，实际时机由 dismissesPopover 决定。 |

`PopoverAction` 默认先关闭，再执行 handler；`dismissesPopover: false` 则立即执行 handler 并保留弹窗。`.destructive` 只表示操作的视觉角色，不会自动增加二次确认或执行删除逻辑。

动作集合在初始化时提供。需要分组、多选、拖拽排序或 loading 流程时，使用自定义内容或业务子类。

<a id="toast"></a>

### 3.4 抽屉式列表

阅读器那种「标题 + 抓手 + 分组列表」的底部抽屉，用法沿用旧实现：先建面板，再按分区逐个加行，提交结果通过 `selectAction` 回传。

```swift
let drawer = BoneDrawerSheetView(title: "阅读设置")
drawer.addButton(text: "平移", value: "0", inSection: .singleSelect("翻页", true))
drawer.addButton(text: "仿真", value: "1", inSection: .singleSelect("翻页", false))
drawer.addButton(text: "浅色", value: "light", inSection: .multipleSelect("主题", false))
drawer.addButton(text: "深色", value: "dark", inSection: .multipleSelect("主题", false))
drawer.addButton(text: "恢复默认", style: .highlight, inSection: .normal("")) {
    print("恢复默认")
}
drawer.sheetConfig.openSectionTitle = true
drawer.selectAction { selections in
    // [(text: String, value: String)]
    print(selections)
}
drawer.show(from: presenter)
```

- 分区类型：`.normal` 点击执行回调并关闭；`.singleSelect` 分区内单选；`.multipleSelect` 分区内多选；`.drag` 按添加顺序全部提交（当前版本不支持拖动排序）。
- 标题相同即同一分区，第二个参数只决定新行是否默认选中；有选择型分区时才出现“确定”按钮，`selectAction` 在点“确定”后回调。
- `sheetConfig` 可调 `openSectionTitle`、`sectionHeight`、`fontSize`、`cellHeight`、`highlightColor`、`textAlignment`，以及颜色相关：`cellBackgroundColor`（行背景，默认 `.secondarySystemBackground`）、`cellCornerRadius`（分组首尾行圆角，默认 10 点）、`horizontalInset`（行背景距面板边缘，默认 16 点）、`cellSeparatorColor`（行间分隔线，默认系统分隔色）。
- 面板底色由 `configuration.appearance.backgroundColor` 控制（`.bottomSheet` 预设为 `systemBackground`），与行背景相互独立。
- 头部布局与阅读器一致：标题居中，**左侧关闭按钮**（与操作列表相同的向下箭头，iOS 26+ 为液态玻璃圆圈，可用 `contentStyle.closeButtonImage` / `closeButtonSize` 换图标与尺寸）、**右侧确定按钮沿用同一套圆圈外观**（同高度、同胶囊圆角、同底色，只是内容从图标换成文字），**右侧按钮默认隐藏**，需要统一提交时再打开 `showsConfirmButton`。
- 两种取结果方式：
  - **多选（或单选也要统一提交）**：`drawer.showsConfirmButton = true`，点右侧按钮统一提交，`selectAction` 回传全部选中项并关闭；
  - **单选/立即执行**：用 `.normal("")` 行加 `callback`，点行即回调并关闭，右侧按钮保持隐藏（原实现的单选用法）。
- 右侧按钮可接管：`drawer.trailingButton` 改文案/图标，或 `drawer.onTrailingButtonTap` 完全接管点击（接管后按钮显示且不自动提交关闭）；`confirmTitle`、`closeAccessibilityLabel` 分别改确定文案与关闭按钮的辅助功能标签。
- 表面沿用 `.bottomSheet`（仅圆顶部两角、无阴影、0.15 秒滑入），默认显示抓手、标题居中。

### 3.5 Toast 提示

`BoneToastView` 支持顶部长条、底部长条和居中方块，以及成功、失败、提示、加载中四种类型。类型与布局独立组合；**四种类型均默认显示 2 秒，包括加载中**。默认无遮罩、允许外部触摸穿透，不会因点击底层页面自动消失。独立 Window 模式默认使用 `.preserveCurrent` 保留当前 key Window。

```swift
BoneToastView(message: "保存成功", type: .success, style: .top).show(from: presenter)
BoneToastView(message: "操作失败", type: .failure, style: .bottom, duration: 3).show(from: presenter)
BoneToastView(message: "有新消息", type: .info, style: .center).show(from: presenter)

let toast = BoneToastView(message: "正在加载", type: .loading, style: .center)
toast.configuration.appearance = .liquidGlass
toast.show(from: presenter)
```

每个实例独立显示和计时，不提供全局排队或自动替换。以上调用分别演示各自用法，业务中按需选择。`type: BoneToastView.ToastType` 支持：

| 类型 | 名称 | 默认指示器 | 默认自动关闭 |
| --- | --- | --- | --- |
| `.success` | 成功 | 绿色 `checkmark.circle.fill` | 2 秒 |
| `.failure` | 失败 | 红色 `xmark.circle.fill` | 2 秒 |
| `.info` | 提示 | 蓝色 `info.circle.fill` | 2 秒 |
| `.loading` | 加载中 | 原生 UIActivityIndicatorView | 2 秒 |

显示期间修改 `type` 会立即切换指示器，并按当前 `duration` 重新计时。进度圈在展示时开始动画，关闭、宿主移除或切换到非加载类型时停止；再次显示加载类型会恢复动画。

| `style` | 形态与尺寸 | 指示器位置 | 默认动画与拖拽 |
| --- | --- | --- | --- |
| `.top` | 顶部长条，填满可用宽度，最大 560 点，高度随内容 | 文字 leading 侧 | 从顶部滑入，可向上滑动关闭 |
| `.bottom` | 底部长条，填满可用宽度，最大 560 点，高度随内容 | 文字 leading 侧 | 从底部滑入，可向下滑动关闭 |
| `.center` | 居中方块，从 160 点起随内容增大，最大 280 × 280 点 | 文字上方 | 缩放淡入，默认禁止拖拽 |

三种布局都避让安全区、键盘及保留区域；小空间下继续缩小，超长内容在内部滚动，居中款仍保持方块轮廓。字体支持 Dynamic Type。默认毛玻璃材质，可像其他弹窗一样配置经典、液态玻璃或品牌色外观。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `type` | 提示类型 | `.info` | `.success` / `.failure` / `.info` / `.loading`，可在显示期间切换并重新计时。 |
| `style` | 布局样式 | `.bottom` | 初始化时确定，只读；`.top` / `.bottom` / `.center`。 |
| `message` | 提示文字 | 初始化时必传 | 显示期间修改自动重新测量。 |
| `image` | 自定义图标 | `nil` | 覆盖非加载类型的图标；nil 恢复类型默认图标。加载中仍显示进度圈，切回其他类型后恢复自定义图标。 |
| `duration` | 停留秒数 | `2` | 展示完成后计时，修改时重新计时；非正值或非有限值禁用自动关闭。对四种类型均生效。 |
| `messageLabel` | 文字控件 | UILabel | 字体、颜色、对齐由 contentStyle 刷新；更新文案请使用 message。辅助功能 value 表示当前类型。 |
| `imageView` | 图标控件 | UIImageView | 类型图标使用对应语义色，自定义图标使用正文颜色；加载中隐藏。 |
| `loadingIndicator` | 加载指示器 | UIActivityIndicatorView | 使用正文颜色；长条为 medium、方块为 large，组件自动管理动画。 |

Toast 使用 `configuration.contentStyle` 中的 `messageFont`（默认 16 点 medium）、`messageColor`（默认 `.label`）、`messageAlignment`（长条 `.natural`，方块 `.center`）、`contentInsets`（长条上下 16、leading/trailing 20；方块四边 24）、`titleToContentSpacing`（用作图文间距，默认 12）和 `adjustsFontForContentSizeCategory`。其他标题、按钮和输入字段不参与 Toast 布局。

需要持续加载时，显式传入 `duration: 0`；操作完成后更新文字、类型和停留时长：

```swift
let loading = BoneToastView(message: "正在加载", type: .loading, style: .center, duration: 0)
loading.show(from: presenter)

// 在主线程的操作完成回调中更新：
loading.message = "加载完成"
loading.type = .success
loading.duration = 2
```

也可以调用 `hidden()` / `dismissPopover()` 手动关闭。自动关闭与程序关闭均不经过 `shouldDismiss`。手动关闭、宿主移除和再次展示会取消旧计时，不占用调用方的 `onDidShow` / `notificationDismissComplete` 回调。子类覆盖生命周期和 `notificationHidden(type:)` 时需调用 super，以保留计时与进度圈管理。

沿用全部展示入口：`show(from:)`、`show(over:)`、`show(in:)`、`show()`；返回 Bool，展示失败不启动计时。无遮罩和穿透是 Toast 初始化时的默认配置，整份替换 `configuration` 会覆盖这些设置。默认穿透时使用 VoiceOver announcement 播报类型与提示文字，不切走当前辅助功能焦点。

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

下表字段通过 `configuration.contentStyle` 访问，默认值来自 `PopoverContentStyle()`。字体为基础 `UIFont`，尺寸和间距单位为点。

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
| `closeButtonImage` | 操作列表关闭按钮图标 | `nil` | `nil` 使用 12 点 medium 的 `chevron.down`；替换后仍沿用标题色。 |
| `closeButtonSize` | 操作列表关闭按钮边长 | 40 点 | 方形命中区；非有限或非正值回退 40 点。 |
| `adjustsFontForContentSizeCategory` | 动态字号 | `true` | 随系统文字大小缩放基础字体；设为 `false` 使用固定字号。 |
| `buttonLayout` | Alert 按钮排列 | `.automatic` | 支持自动、等宽横排、等宽竖排；操作列表始终竖排。 |

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

### 5.2 外观字段

字段通过 `configuration.appearance` 访问，下表默认值来自 `PopoverAppearance()`。`.classic` 将材质设为纯色、圆角设为 16 点；`.bottomSheet` 采用阅读器默认样式——纯色表面、`systemBackground`、圆角 16 点仅顶部两角、无抓手、无背景遮罩且不叠加阴影。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `material` | 面板材质 | `.automatic` | 支持自动、纯色、系统模糊和原生液态玻璃。 |
| `backgroundColor` | 面板背景色 | `.secondarySystemBackground` | 用于纯色材质及降低透明度时的回退。 |
| `tintColor` | 玻璃染色 | `nil` | 原生液态玻璃的染色；模糊回退效果可能不同。 |
| `cornerRadius` | 面板圆角 | 24 点 | 面板内容与材质轮廓的圆角半径。 |
| `maskedCorners` | 圆角作用角 | 四角 | 仅这些角应用圆角，映射 CALayer 的 maskedCorners；底部 sheet 可只圆顶部两角。 |
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

### 5.3 玻璃边缘和阴影

原生玻璃直接通过效果视图自身的 `cornerConfiguration` 定义圆角。文字和按钮位于独立前景层，避免材质合成影响清晰度。

玻璃默认使用系统边缘和阴影，不额外叠加普通卡片阴影。确实需要额外阴影时，设置 `appearance.addsShadowToLiquidGlass = true`，再调整 `shadowColor`、`shadowOpacity`、`shadowRadius` 和 `shadowOffset`。经典、模糊和旧系统回退使用这些可配置阴影。

保持业务内容和 `baseView` 背景透明，避免不透明业务底色盖住玻璃；对玻璃祖先再添加遮罩或裁切，也可能切掉边缘光影。

### 5.4 完全替换背景

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
| `.bottomSheet` | 底部，贴底、无外部留白 | 560 点 | 底部滑入（0.15 秒） | 开，自动向下 |
| `.centerDialog` | 居中 | 420 点 | 缩放 | 关 |
| `.topBanner` | 顶部 | 560 点 | 顶部滑入 | 开，自动向上 |
| `.sidePanel` | trailing 侧，高度填满 | 400 点 | trailing 侧滑入 | 开，自动向外 |

`.bottomSheet` 按阅读器默认样式设定：纯色表面、圆角 16 点仅顶部两角、贴底无外部留白，宽度取所在可用区并受 560 点上限约束，默认不显示背景遮罩和抓手，也不叠加阴影，内置标题默认居中（左对齐时标题从关闭按钮右侧起排，其余对齐按整行计算）。`.topBanner` 的背景遮罩透明度默认是 0.12，不会自动消失；`.centerDialog` 和 `.sidePanel` 默认 0.32。

`BonePopoverView` 无配置初始化时默认使用居中预设；`BonePopoverView(contentView:)` 默认使用底部预设。直接创建 `PopoverConfiguration()` 的默认布局是底部。

整份赋值 `popover.configuration = .bottomSheet` 会重置此前修改的整份配置。建议先选择预设，再修改样式和交互。

`BoneAlertView` 的确认框与输入框在居中预设基础上，额外采用左右各 **32 点外部间距**，以及 **420 × 600 点最大尺寸**。通用 `.centerDialog` 和操作列表的原始默认值不受影响。

### 6.2 布局字段与宽高设置

字段通过 `configuration.layout` 访问，默认值来自 `PopoverLayout()`；预设覆盖值见第 6.1 节。所有几何均使用展示宿主的局部坐标，尺寸单位为点。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `placement` | 面板位置 | `.bottom` | 支持底部、居中、顶部、leading 侧、trailing 侧；两侧位置跟随 RTL。 |
| `width` | 宽度规则 | `.fill` | 使用内容、固定值、可用宽度比例或填满规则。 |
| `height` | 高度规则 | `.content` | 使用内容、固定值、可用高度比例或填满规则。 |
| `maximumWidth` | 最大宽度 | 560 | 限制面板宽度；实际可用空间更小时继续缩小。 |
| `maximumHeight` | 最大高度 | `.greatestFiniteMagnitude` | 默认不额外设置有限上限，仍受当前可用空间约束。 |
| `margins` | 面板外边距 | 四边各 12 | 安全区和排除区域之外，面板与可用区域边缘的最小留白。 |
| `regionPreference` | 可用区域偏好 | `.automatic` | 支持自动、最大区域、leading、trailing、顶部或底部偏好。 |
| `anchorPoint` | 关联位置 | `nil` | 提供宿主坐标中的触发点，优先选择与该点相关的可用区域。 |
| `avoidsKeyboard` | 避让键盘 | `true` | 从布局空间中排除有效的键盘区域。 |
| `avoidsReservedRegions` | 避让系统保留区域 | `true` | 避让折叠分隔、摄像头遮挡等活动区域；支持自定义区域注入。 |

```swift
let popover = BonePopoverView(configuration: .bottomSheet)
popover.configuration.layout.width = .fill
popover.configuration.layout.height = .fraction(0.7)
popover.configuration.layout.maximumWidth = 600
popover.configuration.layout.maximumHeight = 700
popover.configuration.layout.margins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
popover.show(from: presenter)
```

| `PopoverDimension` 取值 | 名称 | 说明 |
| --- | --- | --- |
| `.content` | 按内容测量 | 使用 Auto Layout 内容或自定义测量结果。 |
| `.fixed(points)` | 固定尺寸 | 请求固定点数，仍受可用区域和最大尺寸约束。 |
| `.fraction(value)` | 按比例 | 使用选定可用区域的宽或高比例，比例限制在 0～1。 |
| `.fill` | 填满区域 | 填满选定可用区域，仍受最大尺寸约束。 |

`.content` 默认主要用于测量内容高度。若需要特定内容宽度，可提供合适的 `preferredContentSize`，或覆盖 `preferredPopoverSize(fitting:)`；默认测量实现会优先使用传入的可用宽度。

布局位置还可选择 `.leading` / `.trailing`。这两个位置随 RTL 语义变化；滑动方向中的 `.left` / `.right` 则始终是物理方向。

### 6.3 Alert 外部间距与 iPad 最大尺寸

```swift
let alert = BoneAlertView(title: "项目设置", message: "确认使用当前设置？") {}
alert.horizontalMargin = 40
alert.maximumSize = CGSize(width: 480, height: 560)
alert.show(from: presenter)
```

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `horizontalMargin` | 左右外边距 | 32 点 | 同时写入 `layout.margins.left` 与 `right`，读取时返回左侧值。 |
| `maximumSize` | 最大面板尺寸 | 420 × 600 点 | 同时设置 `layout.maximumWidth` 与 `maximumHeight`，实际尺寸仍受可用空间限制。 |

这两个属性可在显示前或显示期间修改。外部间距从安全区及折叠区域之外的可用矩形边缘计算，与标题、正文和按钮的 24 点内部边距不同。需要左右不同的间距时，直接修改 `layout.margins`；此时 `horizontalMargin` 读取左侧值。

最大尺寸在 iPad、Duo 和其他窗口尺寸下都生效，不通过机型名称或 `regular` 尺寸类别猜测设备。面板实际宽高取内容请求、最大尺寸和当前可用空间的限制：iPad 全屏不会无限放大，窄分屏、键盘及折叠区域较小时仍会继续缩小；超高内容默认可滚动到操作按钮。

先选择配置预设，再设置 `horizontalMargin` 和 `maximumSize`。之后整份赋值 `alert.configuration = .centerDialog` 等预设，会替换它们对应的底层配置值。请传入非负有限值；负值按 0 处理，非有限值会被忽略。

<a id="outside-touch"></a>

## 7. 背景、外部点击和触摸穿透

字段通过 `configuration` 访问；遮罩颜色和不透明度位于其 `appearance` 中。下表为基础配置默认值，输入框预设禁止外部点击关闭。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `showsBackdrop` | 显示遮罩 | `true` | 只控制视觉遮罩，不控制触摸是否传给底层。 |
| `interfaceStyle` | 界面样式覆盖 | `.unspecified` | 默认跟随宿主与系统；设为 `.light` / `.dark` 固定弹层与遮罩外观，设回 `.unspecified` 恢复继承。 |
| `backdropAccessibilityLabel`（在 `BonePopoverView` 上） | 遮罩辅助功能标签 | `nil` | 默认 `NSLocalizedString("Dismiss")`；赋值后立即生效。 |
| `appearance.backdropColor` | 遮罩颜色 | `.black` | 外部背景遮罩的颜色。 |
| `appearance.backdropOpacity` | 遮罩不透明度 | 0.32 | 遮罩的视觉浓度；顶部通知预设为 0.12。 |
| `dismissOnBackdropTap` | 外部点击关闭 | `true` | 不穿透时，点击面板外部是否请求关闭；输入框预设为 `false`。 |
| `allowsEventPenetration` | 外部触摸穿透 | `false` | 是否让面板外部触摸进入底层页面或窗口。 |
| `autoHideWhenPenetrated` | 穿透后关闭 | `false` | 穿透模式下，真实点击结束后是否同时请求关闭。 |

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

字段位于 `configuration`，默认值来自 `PopoverConfiguration()`；居中预设将拖拽总开关设为 `false`。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `allowsDragToDismiss` | 启用拖拽关闭 | `true` | 拖拽总开关；关闭时不响应任何关闭方向。 |
| `allowedSwipeDirections` | 允许关闭方向 | `.automatic` | 设置物理方向组合，或根据面板位置自动选择。 |
| `swipeThreshold` | 关闭阈值 | 100 点 | 沿关闭方向的投影距离达到阈值时关闭；快滑包含速度贡献。 |

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

### 9.1 动画预设

| 取值 | 名称 | 默认参数 | 说明 |
| --- | --- | --- | --- |
| `.slide(edge)` | 边缘滑入 | 0.32 秒、阻尼比 1 | 支持顶部、底部、leading 与 trailing 边缘。 |
| `.fade` | 淡入淡出 | 0.2 秒、阻尼比 1 | 隐藏端点不透明度为 0。 |
| `.scale` | 缩放 | 0.25 秒、阻尼比 1 | 隐藏端点缩放至 0.92，并将不透明度设为 0。 |
| `.spring` | 弹簧缩放 | 0.4 秒、阻尼比 0.82 | 隐藏端点缩放至 0.88，并将不透明度设为 0。 |
| `.none` | 无动画 | 0 秒 | 立即展示或关闭。 |

### 9.2 动画字段

字段通过 `configuration.animation` 访问。`PopoverAnimation` 初始化时必须提供 `hiddenState`，`duration` 和 `dampingRatio` 的默认参数如下；各预设可覆盖它们。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `duration` | 动画时长 | 0.32 秒 | 展示与程序关闭的过渡时长；初始化时负值按 0 处理。 |
| `dampingRatio` | 阻尼比 | 1 | 小于 1 时有弹性；初始化时限制在 0.1～1。 |
| `hiddenState` | 隐藏端点闭包 | 初始化时必传 | 接收面板 frame、容器 bounds 和 RTL 状态，返回 `PopoverVisualState`。 |

隐藏端点闭包的三个参数如下，名称可由调用方自定义：

| 参数 | 名称 | 类型 | 说明 |
| --- | --- | --- | --- |
| `panel` | 面板矩形 | `CGRect` | 当前布局计算出的面板 frame，使用宿主局部坐标。 |
| `container` | 容器矩形 | `CGRect` | 当前展示宿主的 bounds。 |
| `isRightToLeft` | 从右向左布局 | `Bool` | 根据界面布局方向解析 leading/trailing。 |

`PopoverVisualState` 定义自定义动画的隐藏端点：

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `transform` | 几何变换 | `.identity` | 隐藏端点的平移、缩放等变换。 |
| `opacity` | 不透明度 | 1 | 隐藏端点的不透明度；设为 0 可配合淡入淡出。 |

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

下表列出 `BonePopoverView` 的回调、关闭方法与只读状态；“—”表示方法本身没有字段默认值。

| 字段或方法 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `onDidShow` | 展示完成回调 | `nil` | 展示完成后调用；中途关闭不会进入此回调。 |
| `shouldDismiss` | 关闭请求拦截 | `nil` | 接收关闭原因，返回是否允许外部点击、穿透、滑动或辅助功能关闭。 |
| `notificationDismissComplete` | 关闭完成回调 | `nil` | 每次实际关闭完成并清理后调用一次。 |
| `notificationHidden(type:)` | 关闭原因钩子 | 默认空实现 | 子类可覆盖，实际移除后调用，参数为关闭原因。 |
| `hidden(completion)` | 程序关闭 | — | 直接请求关闭，资源移除后执行 completion。 |
| `dismissPopover(animated:reason:completion:)` | 指定方式关闭 | — | 可选择是否动画、关闭原因和 completion。 |
| `presentationState` | 展示状态 | `.hidden` | 只读；取值为 hidden、presenting、presented 或 dismissing。 |
| `isPresented` | 是否处于展示流程 | `false` | 只读；非 hidden 时均为 true，包含关闭动画期间。 |

重复关闭请求的 completion 会合并到同一次实际关闭后，各执行一次；实际关闭通知只发一次。实例关闭后可再次使用。

### 10.1 关闭原因

| `PopoverDismissReason` | 来源 |
| --- | --- |
| `.normal` | 程序关闭，内置确认 / 取消等直接关闭 |
| `.penetration` | 外部点击关闭，包括穿透点击后的自动关闭 |
| `.slide` | 滑动关闭 |
| `.accessibility` | 辅助功能退出手势 |
| `.hostRemoved` | 展示宿主离开窗口后自动清理 |

`CLPopoverDismissType` 是 `PopoverDismissReason` 的类型别名；编写穷举 switch 时应处理表中的全部关闭原因。

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

`configuration.layout.avoidsKeyboard` 默认为 `true`。组件将键盘区域纳入可用空间计算，并尝试让弹窗内的输入焦点保持可见。`isShowKeyboard` 和 `keyboardFrameEnd` 提供只读键盘状态，后者使用屏幕坐标，业务通常无需再次按键盘高度上移内容。

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

### 13.1 配置字段总表

字段位于 `popover.configuration`。下表默认值来自直接创建的 `PopoverConfiguration()`；`BonePopoverView` 无配置初始化使用 `.centerDialog`，传入自定义内容且省略配置时使用 `.bottomSheet`。整份赋值 `configuration` 会替换全部字段，预设覆盖值见 [布局预设](#layout)。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `appearance` | 材质外观 | `PopoverAppearance()` | 材质、背景、圆角、边框、阴影和抓手，见 [外观字段](#appearance)。 |
| `contentStyle` | 内容样式 | `PopoverContentStyle()` | 字体、颜色、对齐和内部间距，见 [内容样式字段](#titles)。 |
| `window` | 独立窗口配置 | `PopoverWindowConfiguration()` | 层级、叠加、key 与容器；创建时保存快照，见 [窗口字段](WindowPresentation.md#窗口配置)。 |
| `layout` | 面板布局 | `PopoverLayout()` | 位置、尺寸、外部边距及区域避让，见 [布局字段](#layout)。 |
| `animation` | 展示与关闭动画 | `.slide(.bottom)` | 时长、阻尼与隐藏端点，见 [动画字段](#animation)。 |
| `showsBackdrop` | 显示遮罩 | `true` | 控制外部背景遮罩的视觉显示。 |
| `dismissOnBackdropTap` | 外部点击关闭 | `true` | 不穿透时点击外部请求关闭；输入框预设为 false。 |
| `allowsEventPenetration` | 外部触摸穿透 | `false` | 将面板外部触摸交给底层页面或窗口。 |
| `autoHideWhenPenetrated` | 穿透后关闭 | `false` | 穿透模式下在真实外部点击结束后请求关闭。 |
| `allowsDragToDismiss` | 启用拖拽关闭 | `true` | 拖拽总开关；居中预设默认 false。 |
| `allowedSwipeDirections` | 允许关闭方向 | `.automatic` | 支持物理方向组合或按面板位置自动选择。 |
| `swipeThreshold` | 关闭阈值 | 100 点 | 用沿关闭方向的投影距离判断，见 [滑动说明](#swipe)。 |
| `respectsReduceMotion` | 跟随减弱动态效果 | `true` | 系统开启减弱动态效果时使用短时淡入淡出。 |
| `respectsReduceTransparency` | 跟随降低透明度 | `true` | 系统开启降低透明度时将内置材质回退为纯色。 |
| `scrollsOverflow` | 超高内容滚动 | `true` | 内容超过可用高度时提供滚动；自管滚动内容可关闭。 |

### 13.2 常用组件属性

以下属性直接位于 `BonePopoverView`，不在 `configuration` 中。回调与展示状态见 [回调字段](#lifecycle)。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `configuration` | 整体配置 | `.centerDialog` | 无配置初始化时的预设；显式传入配置时使用调用方的值。 |
| `baseView` | 内容容器 | 透明 `UIView` | 自定义控件的容器，其 bounds 为内容区域。 |
| `customBackgroundView` | 自定义材质背景 | `nil` | 设置后替换内置材质；设回 nil 恢复 appearance。 |
| `reservedRegionProvider` | 自定义保留区域 | `nil` | 返回展示宿主局部坐标中的排除矩形；nil 时使用系统查询。 |
| `preferredContentSize` | 明确内容尺寸 | `.zero` | 高度大于 0 时优先用于内容测量，结果仍受布局空间限制。 |
| `popupType` | 位置与动画快捷设置 | `.alert` | 设为 alert、sheet、fadeIn 时映射对应位置或动画，不替代完整配置。 |
| `key` | 实例标识 | 实例 UUID 字符串 | 只读；同一实例重显时保持稳定，每次展示另有内部会话身份。 |
| `isShowKeyboard` | 键盘可见状态 | `false` | 只读；当前弹窗关联的键盘是否可见。 |
| `keyboardFrameEnd` | 键盘结束矩形 | `.zero` | 只读；键盘通知中的屏幕坐标矩形。 |

### 13.3 Alert 便利属性

以下属性直接位于 `BoneAlertView`，可在展示前或显示期间修改；整份替换 configuration 会覆盖映射到配置中的值。

| 字段 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `titleAlignment` | 标题对齐 | `.left` | 直接读写 `contentStyle.titleAlignment`；操作列表也提供同名属性。 |
| `buttonLayout` | 按钮排列 | `.automatic` | 直接读写 `contentStyle.buttonLayout`。 |
| `horizontalMargin` | 左右外边距 | 32 点 | 同时设置左右外边距；读取时返回左侧值。 |
| `maximumSize` | 最大面板尺寸 | 420 × 600 点 | 同时设置面板最大宽高。 |
| `keyboardType` | 输入键盘类型 | `.default` | 映射输入预设的 UITextField 键盘类型。 |
| `text` | 输入内容 | 空字符串 | 读取或设置输入框文字，可预填初始值。 |

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
- “Toast 顶部长条 / 底部长条 / 中间方块”：默认显示成功类型，2 秒后自动关闭；导航栏“Toast”菜单可选择成功、失败、提示、加载中，以及 1 / 2 / 3 / 5 秒或持续显示。显示期间切换类型/时长立即生效，也可以点击底层列表切换布局场景。
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

### 14.3 接入已有项目

从其他弹窗实现切换时，按页面选择内置预设、自定义内容或子类，并确认展示范围、尺寸测量与回调时机。具体映射见 [迁移说明](Migration.md)。独立窗口的层级、导航与 Scene 行为见 [窗口说明](WindowPresentation.md)。

### 14.4 已验证到什么程度

已完成 iOS 15 部署目标 / Swift 6 严格类型检查、24 组手册与窗口示例编译、59 项核心回归，以及 iPad 的 22 项窗口托管测试。窗口测试覆盖创建快照、固定/自动层级、key 与输入恢复、穿透观察器清理、回调重入、实际对象释放、导航栈及真实双 Scene 隔离和销毁；独立 Window 内的窄宿主、横竖保留区域、键盘通知与材质切换也在 iPhone / iPad / Duo 通过定向验证。手机和平板实际点击、各次失败与复测，以及新版 Demo 安装启动结果统一见 [验证记录](Validation.md)。

这些记录不表示所有系统版本和实体设备都完成验收。Duo 模拟器支持第二 Scene 激活，但系统拒绝主动销毁，相关阶段明确跳过，不能代替 iPad 的销毁隔离结果。iOS 15 没有实际运行验证；实体 Duo 全姿态、全部 iPadOS 窄分屏组合和完整辅助功能人工验收尚未完成；此前 iOS 27.1 连续输入后点击问题仍独立记录。原组件分布见 [项目清单](Inventory.md)。
