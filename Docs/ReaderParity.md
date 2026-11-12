# 阅读器旧弹层与 BonePopoverKit 的可配置项对照

参照实现：ParsingBook `ParsingBook/Custom/BonePopoverView/`（`Basics/BonePopoverView.swift`、`Basics/CLPopoverManager/*`、`BoneSheetView/*`）。
对照版本：BonePopoverKit `main`（本仓库，iOS 15+，tools 5.9）。

统一规则：**不设置就是默认值**。所有新增入口的默认值与原行为逐字一致，旧调用不迁移、不改渲染结果；只有显式赋值才改变外观或交互。

## 1. 阅读器写死、SDK 原本也没有入口的项（本轮补成可配置）

| 阅读器中的写死值 | 位置（阅读器） | SDK 新增入口 | 默认值（= 旧行为） |
| --- | --- | --- | --- |
| 确认 / 取消按钮文案 | SDK `Sources/BonePopoverKit/PopoverPresets.swift:116-117` 写死；阅读器由各 alert 子类自建按钮 | `configuration.buttonTitles.confirm` / `.cancel`；`alert.confirmTitle` / `alert.cancelTitle` | `nil` → “确认”“取消” |
| 关闭按钮图标（bundle 图片） | 各 sheet 子类 `backButton` | `contentStyle.closeButtonImage` | `nil` → 12 点 medium `chevron.down` |
| 关闭按钮命中区 40 × 标题高 | 各 sheet 子类 `width(40)` | `contentStyle.closeButtonSize` | `40` 点 |
| 缩放动画固定 0.8 + 淡出 | `BonePopoverView.swift:117` | `PopoverAnimation.scale(0.8)` | `.scale` = 0.92 / 0.25 秒 |
| 全局强制浅色（`BoneThemeManager`） | `BonePopoverView.swift:29-47` | `configuration.interfaceStyle` | `.unspecified`（跟随宿主与系统） |

用法示例：

```swift
let alert = BoneAlertView(title: "删除项目", message: "删除后不可恢复") {}
alert.confirmTitle = "OK"          // 或 alert.configuration.buttonTitles.confirm = "OK"
alert.cancelTitle = "Cancel"
alert.configuration.interfaceStyle = .light   // 固定浅色；不设置则跟随宿主
alert.show(from: presenter)

let sheet = BoneActionSheetView(title: "项目操作", actions: [PopoverAction("分享")])
sheet.configuration.contentStyle.closeButtonImage = UIImage(systemName: "xmark")
sheet.configuration.contentStyle.closeButtonSize = 52
sheet.configuration.animation = .scale(0.8)    // 阅读器那种收放幅度

alert.configuration.animation = .scale(0.8)
```

## 2. 阅读器写死、SDK 早已可设（仅补文档，无代码改动）

| 阅读器写死值 | SDK 对应配置 | SDK 默认 |
| --- | --- | --- |
| `baseView.layer.cornerRadius = 16` | `appearance.cornerRadius` | 24（`.bottomSheet` 为 16） |
| sheet 只圆顶部两角 | `appearance.maskedCorners` | 四角（`.bottomSheet` 仅上两角） |
| 遮罩 `.black.withAlphaComponent(0.6)`，且只有开/关开关 | `appearance.backdropColor` / `backdropOpacity` / `showsBackdrop` | `.black` / 0.32 / 显示 |
| 滑动阈值 100、方向 OptionSet | `swipeThreshold` / `allowedSwipeDirections` | 100 / `.automatic` |
| 窗口层级 `alert - 1` | `window.level` | `.alert - 1` |
| 状态栏/方向/自动旋转（阅读器可配） | 从宿主派生（`PopoverWindowAppearanceContext`） | 继承宿主 |
| 键盘监听开关 + 手工避让 | `layout.avoidsKeyboard` | 自动避让 |
| 标题 18 点粗、颜色、居中 | `contentStyle.titleFont/titleColor/titleAlignment` | 18 粗 / `.label` / 左（`.bottomSheet` 居中） |
| 是否点击外部关闭、穿透、穿透后自动关 | `dismissOnBackdropTap` / `allowsEventPenetration` / `autoHideWhenPenetrated` | 关闭 / 否 / 否 |

## 3. 明确不采纳的部分（属于宿主或业务）

| 阅读器能力 | 不采纳原因 |
| --- | --- |
| 队列 / 优先级 / 插队 / 替换 / 唯一 / `identifier` 去重 | 多弹窗调度是宿主协调器职责；SDK 只保证单次展示与关闭的回调顺序 |
| 表格 section 高度、cell 高度、勾选图标、`SheetConfig` 配色 | 属于具体业务列表内容，由宿主自定义内容或子类实现 |
| 强制浅色阅读主题、状态栏与方向锁定 | 通过 `interfaceStyle` 之外的产品级策略仍归宿主；SDK 只提供可选覆盖，不内置阅读器策略 |
| `BonePopoverIcon.bundle` 图标资源 | 宿主提供图标（新的 `closeButtonImage` 已能覆盖内置箭头） |

## 4. 兼容性

- 新增字段全部带默认值：`PopoverButtonTitles()`、`.unspecified`、`closeButtonSize = 40`、`closeButtonImage = nil`、`PopoverAnimation.scale` 仍为 0.92。
- `configuration.buttonTitles` 修改会立即刷新已加载的按钮并重新测量面板；`closeButtonSize` 会同步宽高约束与标题前置约束。
- `interfaceStyle` 取消覆盖（设回 `.unspecified`）会同时把宿主视图与弹层恢复为继承，不残留固定样式。
- 验证：`Tests/BonePopoverKitTests/PopoverReaderParityTests.swift`（5 项）覆盖上述默认值与覆盖路径；记录见 [Validation](Validation.md)。
