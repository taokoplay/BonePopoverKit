# 更新日志

本文件记录各版本的功能调整、修复与升级影响。完整接入方式见 [使用说明](Docs/UsageGuide.md)，旧调用替换方式见 [迁移指南](Docs/Migration.md#action-sheet-migration)。

<a id="unreleased"></a>

## 未发布

暂无新增变更。

<a id="v0.1.0"></a>

## v0.1.0 — 2026-11-14

### 不兼容变更

- 默认底部操作列表统一使用基于 `UITableView` 的 `BoneDrawerSheetView`。删除 `BoneActionSheetView`、`PopoverAction` 及旧渲染器，不提供兼容别名。
- 旧 `actions` / `addAction`、返回 `UIButton` 的 `addButton` 和 `actionButtons` 改为逐行调用 `addButton(text:...)`。新方法返回 `Void`，辅助功能标识通过 `accessibilityIdentifier:` 参数传入。
- 操作列表默认没有底部取消行，使用左侧关闭箭头。旧操作列表的 `cancelButton` / `cancelTitle` 需迁移到 `closeButton` / `showsCloseButton` / `closeAccessibilityLabel`；Alert 自身的取消按钮与文案入口保留。
- 操作列表行字体、行高及间距通过 `sheetConfig` 设置；`contentStyle.buttonFont` / `buttonSpacing` / `buttonLayout` 继续用于 Alert。标题、说明及关闭按钮样式使用 `contentStyle`。

### 新增与调整

- `BoneDrawerSheetView(title:message:)` 支持可选说明文字；普通动作支持图标、`.destructive` 红色样式和自定义行标识。普通行默认关闭并移除后回调，`dismissesPopover: false` 立即回调并保持打开。
- 单选、多选、同分区拖动和固定高度滚动均为同一组件的变体。选择结果通过 `showsConfirmButton = true` 与 `selectAction` 提交；右侧按钮默认隐藏，`onTrailingButtonTap` 可接管其行为。
- 面板使用 `systemGroupedBackground`，行背景使用 `secondarySystemGroupedBackground`，浅色下为灰底白行，深色随系统分组颜色调整；保留顶部抓手和左侧向下箭头。标题为 17 点 semibold，说明 14 点，关闭按钮 40 × 40 点；表头左右留白 16 点、标题上下最小留白 10 点、列表间距 16 点，行字体 16 点粗体、行高 55 点。
- 长列表默认使用 500 点列表高度上限并内部滚动；`maximumListHeight` 的有效下限为 120 点。列表自行滚动，默认关闭外层 `scrollsOverflow`。
- 玻璃遮罩与压暗程度独立配置：开启 `showsBackdrop` 与 `appearance.backdropGlass` 后，可通过 `backdropOpacity = 0` 只虚化背景，或提高不透明度叠加压暗。默认不开启玻璃遮罩，系统降低透明度设置仍生效。
- Demo 保留 23 个场景编号。默认操作列表、实时字体/行高/间距、玻璃遮罩和选择/排序/滚动变体均使用统一组件。

### 修复

- 贴底弹层的面板材质延伸至底部安全区，消除底部白边，内容继续避让安全区；正值底部外边距及键盘、保留区域的避让仍生效。
- `show(from:)` 收到导航或标签容器时选择当前内容页挂载，避免把 Toast 加入导航返回栈并在右滑时出现黑屏。页面模式覆盖内容页；需要覆盖导航栏、标签栏及整个业务窗口时使用 `show(over:)` 或 `show(in:)`。
- 首次加载操作列表时应用标题与说明样式。关闭按钮改尺寸后保持表头垂直居中，不对称内容边距不会推偏居中标题。

### 升级与验证

升级前先按 [操作列表迁移表](Docs/Migration.md#action-sheet-migration) 替换已删除的 API，再核对 [当前参数与默认值](Docs/UsageGuide.md#action-sheet)。玻璃遮罩示例见 [使用说明](Docs/UsageGuide.md#backdrop-glass)。

最近一次实现变更已完成以下检查，本次文档整理没有重跑运行时测试：

| 检查 | 结果 |
| --- | --- |
| iPhone Duo / iOS 27.1 核心回归 | 108/108 通过 |
| iPhone 17 Pro / iOS 26 Demo UI 回归 | 14/14 通过 |
| 表头修正后的布局与玻璃遮罩定向复测 | 5/5 通过，与上述 UI 用例存在重叠 |
| 真机 Demo 构建 | 通过 |

UI 中的排序变体只验证分区打开与行展示，未执行真实拖动手势。完整执行范围、历史失败与复测、真机安装状态见 [验证记录](Docs/Validation.md#unified-operation-list)。
