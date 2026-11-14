# 阅读器旧弹层与 BonePopoverKit 的可配置项对照

参照实现：ParsingBook `ParsingBook/Custom/BonePopoverView/`（`Basics/BonePopoverView.swift`、`Basics/CLPopoverManager/*`、`BoneSheetView/*`）。
对照版本：BonePopoverKit `main`（本仓库，iOS 15+，tools 5.9）。

当前底部操作列表统一使用基于 UITableView 的 `BoneDrawerSheetView`，普通动作、单选、多选、同分区拖动和固定高度滚动都是它的变体。**旧 `BoneActionSheetView`、`PopoverAction` 已删除，不提供兼容 alias**；历史调用需按[操作列表迁移](Migration.md#action-sheet-migration)调整。未定制的字段使用当前组件默认值，不能据此假定旧操作列表可原样编译或保持旧布局。

## 1. 阅读器写死、SDK 原本也没有入口的项（本轮补成可配置）

| 阅读器 / 早期 SDK 中的写死值 | 位置或用途 | 当前 SDK 入口 | 当前默认值 |
| --- | --- | --- | --- |
| Alert 确认 / 取消按钮文案 | 阅读器由各 alert 子类自建按钮；早期 SDK 为字面量 | `alert.confirmTitle` / `alert.cancelTitle` | `nil` → “确认”“取消” |
| 选择提交按钮文案 | 抽屉右侧按钮 | `sheet.confirmTitle` | `nil` → “确定”；按钮默认隐藏，需 `showsConfirmButton = true` |
| 关闭按钮图标（bundle 图片） | 各 sheet 子类 backButton | `contentStyle.closeButtonImage` | `nil` → 12 点 medium `chevron.down` |
| 关闭按钮命中区 40 × 标题高 | 各 sheet 子类 width(40) | `contentStyle.closeButtonSize` | 40 × 40 点；右侧按钮共用这一尺寸 |
| 缩放动画固定 0.8 + 淡出 | 阅读器 BonePopoverView.swift:117 | `PopoverAnimation.scale(0.8)` | `.scale` = 0.92 / 0.25 秒 |
| 全局强制浅色（BoneThemeManager） | 阅读器 BonePopoverView.swift:29-47 | `configuration.interfaceStyle` | `.unspecified`，跟随宿主与系统 |
| 关闭按钮标签、遮罩标签、Toast 类型描述 | 组件辅助功能文案 | `sheet.closeAccessibilityLabel`、`popover.backdropAccessibilityLabel`、`toast.typeDescriptions` | `nil` → “关闭” / `NSLocalizedString("Dismiss")` / “成功”“失败”“提示”“加载中” |

用法示例：

```swift
let alert = BoneAlertView(title: "删除项目", message: "删除后不可恢复") {}
alert.confirmTitle = "OK"
alert.cancelTitle = "Cancel"
alert.configuration.interfaceStyle = .light
alert.configuration.animation = .scale(0.8)
alert.show(from: presenter)

let sheet = BoneDrawerSheetView(title: "项目操作", message: "选择要执行的操作")
sheet.addButton(text: "分享", icon: UIImage(systemName: "square.and.arrow.up"),
                accessibilityIdentifier: "sheet-share") {
    print("弹窗已关闭，执行分享")
}
sheet.addButton(text: "刷新状态", dismissesPopover: false) {
    print("立即刷新，保留面板")
}
sheet.configuration.contentStyle.closeButtonImage = UIImage(systemName: "xmark")
sheet.configuration.contentStyle.closeButtonSize = 52
sheet.closeAccessibilityLabel = "Close"
sheet.show(from: presenter)
```

## 2. 阅读器写死、SDK 已可配置的项

下表区分配置类型的通用默认值与 `BoneDrawerSheetView` 的组件默认值。

| 阅读器写死值或能力 | SDK 对应配置 | 当前默认 |
| --- | --- | --- |
| 面板圆角、只圆顶部两角 | `appearance.cornerRadius` / `maskedCorners` | 通用外观 24 点 / 四角；bottomSheet 与操作列表为 16 点 / 顶部两角 |
| 遮罩颜色、浓度、虚化和显示 | `appearance.backdropColor` / `backdropOpacity` / `backdropGlass`、`showsBackdrop` | 通用配置黑色 / 0.32 / 不虚化 / 显示；操作列表默认不显示背景遮罩 |
| 面板与分组行底色 | `appearance.backgroundColor` / `sheetConfig.cellBackgroundColor` | 操作列表为 systemGroupedBackground / secondarySystemGroupedBackground |
| 抓手 | `appearance.showsGrabber` | 通用 bottomSheet 为 false；操作列表为 true |
| 标题、说明、对齐 | `contentStyle.titleFont` / `messageFont` / `titleColor` / `titleAlignment` | Alert 为 18 点粗体 / 17 点 / label / 左；操作列表为 17 点 semibold / 14 点 / label / 居中 |
| 内容内边距 | `contentStyle.contentInsets` | Alert 四边 24 点；操作列表 top 0、leading 0、bottom 20、trailing 0 |
| 表头左右、标题上下、到列表的间距 | `sheetConfig.headerInset` / `headerTopSpacing` / `listTopSpacing` | 16 / 10 / 16 点 |
| 分区标题与间距 | `sheetConfig.openSectionTitle` / `sectionHeight` | false / 10 点 |
| 行字体、行高、分隔线 | `sheetConfig.fontSize` / `cellHeight` / `cellSeparatorColor` | UIFont 16 点粗体 / 55 点 / separator；系统分隔线关闭，行间自绘 |
| 分组背景圆角与水平留白 | `sheetConfig.cellCornerRadius` / `horizontalInset` | 10 / 16 点 |
| 图标尺寸、圆角、底色、颜色、文字间距 | `sheetConfig.cellIconSize` / `cellIconCornerRadius` / `cellIconBackgroundColor` / `cellIconTint` / `cellIconSpacing` | 32 / 9 / nil / nil / 12 点；nil tint 跟随 highlightColor |
| 长列表高度与滚动 | `sheetConfig.maximumListHeight` | 500 点；超过后内部滚动，操作列表关闭外层滚动 |
| 单选 / 多选 / 排序 | `addButton` 的 `.singleSelect` / `.multipleSelect` / `.drag` 分区 | 选择型分区需 showsConfirmButton = true + selectAction 提交；拖动仅限同分区 |
| 左侧关闭、右侧确定 | `showsCloseButton` / `showsConfirmButton` | true / false；默认没有取消行 |
| 滑动阈值与方向 OptionSet | `configuration.swipeThreshold` / `allowedSwipeDirections` | 100 点 / automatic |
| 窗口层级 alert - 1 | `configuration.window.level` | alert - 1 |
| 状态栏、方向、自动旋转 | 从宿主派生（PopoverWindowAppearanceContext） | 继承宿主 |
| 键盘监听与避让 | `configuration.layout.avoidsKeyboard` | 自动避让 |
| 点击外部关闭、穿透、穿透后关闭 | `dismissOnBackdropTap` / `allowsEventPenetration` / `autoHideWhenPenetrated` | 允许关闭 / false / false；输入框禁止外部点击关闭 |

操作列表标题和说明通过 `message`、公开的 `titleLabel` / `messageLabel` 及 `contentStyle` 配置；行字体、行高、分隔线使用 `sheetConfig`。`contentStyle.buttonFont` / `buttonSpacing` / `buttonLayout` 仍用于 Alert，不控制表格行。贴底时面板材质铺满底部安全区，列表与按钮继续避让；设置底部外边距或避让键盘、保留区域时仍保留对应留白。

`show(from:)` 在内容页内展示，传入导航/标签容器时自动选择当前内容页，不改变导航返回栈或标签列表。覆盖导航栏、标签栏或整个业务窗口时使用 `show(over: sourceWindow)`；多 Scene 可用 `show(in: scene)` 明确目标。

## 3. 继续由宿主或业务管理的部分

| 阅读器能力 | 边界 |
| --- | --- |
| 队列 / 优先级 / 插队 / 替换 / 唯一 / identifier 去重 | 由宿主协调展示；SDK 保证单次展示与关闭的回调顺序 |
| 业务自定义 cell、loading、多字段与 WebKit / 阅读逻辑 | 使用自定义内容或子类逐项适配；分组、选择、同分区排序和行样式已有内置支持 |
| 强制浅色阅读主题、状态栏与方向锁定 | interfaceStyle 之外的产品策略归宿主，不内置阅读器主题管理器 |
| BonePopoverIcon.bundle 图标资源 | 由宿主提供，closeButtonImage 与 addButton 的 icon 可覆盖默认图标 |

## 4. 兼容性与操作列表迁移

- `BoneActionSheetView`、`PopoverAction`、`actions` / `addAction`、`actionButtons`、旧 `cancelButton` / `cancelTitle` 均为**已删除的操作列表 API**。改为 `BoneDrawerSheetView(title:message:)` + `addButton(text:...)`；Alert 自身的 cancelButton / cancelTitle 保留。
- `addButton` 返回 Void，辅助功能标识通过参数传入；旧 image 参数改为 icon，role 改为 style（default / highlight / destructive），handler 改为 callback。普通行默认先关闭再回调，dismissesPopover: false 立即回调并保持面板。
- 选择型分区显式开启 showsConfirmButton 并用 selectAction 提交；右侧按钮的 confirmTitle、trailingButton、onTrailingButtonTap 保留，接管点击后宿主自行处理提交和关闭。
- 字体、颜色与对齐通过 contentStyle 或 sheetConfig 设置，直接改 label 样式会被下一次样式刷新覆盖；整份替换 configuration 会覆盖组件初始化设置。
- interfaceStyle 设回 unspecified 后恢复继承宿主外观。历史验证记录见 [Validation](Validation.md)；本次文档迁移不追加测试或设备验收结论。

## 5. 文案收口（补充）

当前 Alert 使用 `alert.confirmTitle` / `alert.cancelTitle`（默认“确认”“取消”）；操作列表使用 `sheet.confirmTitle`（默认“确定”）与 `sheet.closeAccessibilityLabel`（默认“关闭”），没有默认取消行。`popover.backdropAccessibilityLabel` 与 `toast.typeDescriptions` 分别控制遮罩辅助功能标签与 Toast 类型描述。旧操作列表的 cancelTitle 仅在第 4 节作为删除迁移对照保留。
