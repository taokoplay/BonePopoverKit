# 验证记录

## 环境

- Xcode 27.1（27A9275），Apple Swift 6.4。
- 当前 iOS / iOS Simulator SDK：27.1。
- SDK 和示例 App 最低部署目标：iOS 15.0。
- 示例 UI 与窗口托管测试 runner 最低 iOS 17.0，与本机 XCTest 库最低版本一致，不改变 SDK/App 的 iOS 15 支持。
- 分阶段使用 iPhone Duo / iOS 27.1、iPhone 13 Pro / iOS 26、iPad Pro 11-inch M4 / iOS 26，以及早期 iPhone 16 / iOS 18.6 模拟器。

## 已执行且通过

| 检查 | 结果 |
| --- | --- |
| 全部 SDK 源码，以 `arm64-apple-ios15.0-simulator` 做类型检查 | 通过 |
| 相同目标使用 `-swift-version 6` 严格模式类型检查 | 通过 |
| 单独生成 BonePopoverKit module，外部 client 继承基类并覆盖尺寸、关闭、手势钩子 | 通过 |
| Swift Package 的 iOS 设备目标 Release 构建，关闭签名 | `BUILD SUCCEEDED` |
| 示例 Xcode 工程生成与模拟器构建 | `BUILD SUCCEEDED` |
| iPhone Duo / iOS 27.1 核心测试 | **19/19 通过，0 失败** |
| iPhone Duo / iOS 27.1 真实 UI 测试 | **2/2 通过，0 失败** |
| iPhone 16 / iOS 18.6 核心测试 | **19/19 通过，0 失败** |

最终三条测试命令均以退出码 0 / `TEST SUCCEEDED` 正常完成；最终日志未发现 Auto Layout 约束冲突。iOS 18.6 的样式切换测试实际执行了 Liquid Glass 的旧系统模糊回退分支。

## 核心测试范围

- 非零容器原点、非对称四边安全区。
- 竖向折叠、横向折叠、RTL、摄像头和键盘矩形同时避让。
- 明确 anchor 位于较小区域时保持上下文关联。
- 连续窗口宽度变化、极小容器、完全遮挡。
- 控制器包含关系、重复展示拒绝、关闭后复用。
- 关闭打断出现动画、重复关闭的 completion 各一次。
- 点击背景的关闭拦截与取消拦截。
- 长内容滚动、运行时样式切换保留内容。
- 宿主移除后的清理与自动释放池结束后的对象释放。
- 确认回调在内容和控制器移除后执行。
- `viewDidAppear` 内同步关闭不会恢复错误的 presented 状态。
- `willMove(toParent: nil)` 先于消失生命周期回调。
- 子类测量宽度被 `.content` 模式正确使用。
- 拖拽取消不能覆盖正在进行的程序关闭。
- host bounds 不变但保留区域变化时，关闭动画重新计算退出端点。

## 真实 UI 测试范围

1. 点击确认框、确认；打开输入框、输入文字、确认按钮可点击；打开操作列表，连续切换四次风格，检查其他操作可点击，再取消。
2. 展示注入竖向和横向折叠区域的场景；验证确认按钮可点击，且完整位于区域一侧；取消。

UI 测试保留了中心弹窗、键盘输入、玻璃操作列表、竖向与横向注入折叠的截图附件。区域选择允许系统非对称安全区使另一侧更合适，不错误地断言弹窗必须在整个 App 右半边。

## API 核验与适配边界

本机 SDK 中已直接核验：

- UIKit `UIGlassEffect`：iOS 26.0 起。
- `UIView.reservedRegions(kind:options:)` 和 `UIView.ReservedRegion`：iOS 27.1 起。
- reserved region 的 `frame` 已包括 `margins`；默认查询活动区域。
- 新版接口在源码中同时有编译器条件和系统 availability 保护。

Duo 自动适配实现已接入真实系统区域查询，并在 Duo 模拟器上运行；折叠几何变更由独立注入测试验证。**本次没有操作实体 Duo，也没有逐一切换实际模拟器的所有折叠姿态、摄像头活动状态或分屏组合。** 注入几何通过不能等同于全姿态硬件验收。

本机没有 iOS 15 运行时。本次确认的是 iOS 15 部署目标编译成功，以及 iOS 18.6 / 27.1 的运行测试通过，**不声称已经在 iOS 15 真机运行**。独立旧 Xcode 的编译器回退分支也未构建。

VoiceOver、减弱动态效果、降低透明度有实现，但本次没有完整人工辅助功能巡检。原 App、其 112 个不同子类、CLPopoverManager 排队语义和业务模块未进行集成迁移或构建，详见 [迁移说明](Migration.md)。

## 复现与证据

完整运行命令见 [README](../README.md)。本次测试使用 `-parallel-testing-enabled NO -collect-test-diagnostics never`，防止失败时模拟器诊断收集阻塞测试进程。

本会话 scratch 目录中保留以下日志和结果包（临时证据，随会话清理）：

- `core-regression.log` / `CoreRegression.xcresult`：Duo 19 项核心测试。
- `demo-ui-final.log` / `DemoUIFinal.xcresult`：2 项真实 UI 测试及截图附件。
- `legacy-core.log` / `LegacyCore.xcresult`：iOS 18.6 的 19 项核心测试。
- `device-release.log`：iOS 设备 Release 构建。

最终统计使用上述结果，不使用前期出现过测试宿主事件派发问题、自动释放池断言问题和过强 UI 坐标断言的旧失败记录。相应路径已修复并回归通过。

## 液态玻璃边缘修正

针对 iOS 26.5 真机反馈，改用效果视图自身的 `cornerConfiguration` 定义圆角，移除玻璃祖先层的裁切；文字和按钮保留在玻璃之上的独立前景层并单独裁切，避免材质合成影响清晰度。原生玻璃默认不再叠加自定义卡片阴影，显式 `addsShadowToLiquidGlass` 可恢复额外阴影。

- Swift 6 / iOS 15 目标类型检查通过；iPhone 13 Pro 设备签名构建通过。
- Duo / iOS 27.1 核心测试 23/23 通过，包含新增 4 项材质轮廓、内容层级、回退和阴影回归。
- Duo / iOS 27.1 最新 UI 复测为 1 项通过、1 项失败：注入折叠通过；连续输入场景中输入确认回调已经完成、弹窗已移除，但后续列表项不可点击。失败层级中存在额外全屏空窗口，尚未确认其持有方；不能把这一轮记为全部通过。
- iOS 18.6 第一轮核心测试 22 项通过、1 项按版本跳过；前景分层修正后针对 4 项材质测试再次验证，3 通过、1 跳过、0 失败。
- 最终轮廓与核心证据：`glass-core-foreground.log` / `GlassCoreForeground.xcresult`、`glass-ui-foreground.log` / `GlassUIForeground.xcresult`、`glass-legacy-foreground.log` / `GlassLegacyForeground.xcresult`。
- 截图核查确认独立前景的文字清晰，玻璃自身圆角呈现连续细轮廓。UI 测试增加展示完成和下一场景可点击的等待条件；按场景保留失败证据。
- iPhone 13 Pro / iOS 26.0 模拟器针对性复核 `testConfirmationInputAndLiveStyleSwitch` **1/1 通过**，确认、输入回调、关闭后列表点击、实时风格切换均通过。证据：`glass26-ui.log` / `Glass26UI.xcresult`，截图目录 `glass26`。该结果不能替代 iOS 27.1 的失败记录。
- 已将修正后 Demo 覆盖安装至用户的 iPhone 13 Pro / iOS 26.5，并通过 `devicectl` 成功启动；安装和启动均返回成功。最终真机边缘观感由用户继续体验，本次没有声明已完成真机逐场景视觉验收。

## Duo 内容宽度与标题对齐修正

用户截图中的顶部空白和按钮右侧大块留白，通过导航控制器 + 非对称安全区回归复现：标题距内容顶部实际 150 点（预期 24），确认按钮右边缘少 84 点（与右侧安全区一致），底部留白 58 点（预期 24）。根因是内置 `UIStackView` 在 host 已避让外部安全区后，再次把 safe area 叠加到自身 layout margins。

修正为内容栈仅使用本地 24 点边距，并保持 `.fill` 横向布局。确认框、输入框和操作列表新增 `titleAlignment`，默认 `.left`，支持 `.center` / `.right`，可以在加载前或展示期间修改。标题位于内容顶部，不修改正文对齐。Demo 导航栏增加“标题对齐”菜单。

- iOS 15 / Swift 6 类型检查、模拟器 Demo 构建和 iPhone 13 Pro 签名构建通过。
- Duo / iOS 27.1 核心测试 **26/26 通过**，包括 3 项新布局回归；修复前上述断言确实失败，修复后通过。
- Duo UI 测试 **2/2 通过**：左中右标题、按钮左右边距、标题顶部距离及横竖注入折叠避让。
- iPhone 13 Pro / iOS 26 UI 测试 **2/2 通过**：标题/按钮布局和确认、输入、实时风格切换流程。
- 最终运行日志未发现约束冲突。证据：`title-core.log` / `TitleCore.xcresult`、`title-duo-ui.log` / `TitleDuoUI.xcresult`、`title-phone-ui.log` / `TitlePhoneUI.xcresult`。
- 本轮没有重跑此前 iOS 27.1 的连续输入后点击失败用例，不能据此宣布那一问题已经解决。
- 已对照 Duo 与 iPhone 三种对齐的最终截图，确认标题顶部间距、按钮左右等距及玻璃文字清晰度。新版 Demo 已覆盖安装到用户 iPhone 13 Pro / iOS 26.5，安装和启动均成功。

## 外部触摸与多方向关闭能力补齐

新增独立的 `showsBackdrop`、`allowsEventPenetration`、`autoHideWhenPenetrated`、`allowedSwipeDirections` 和 `swipeThreshold`，保留 `dismissOnBackdropTap` / `allowsDragToDismiss`。背景视觉使用独立子视图，隐藏遮罩或透明度为零不再使点击层失去响应。穿透模式只在真实外部点击结束时按配置请求关闭，不在 `hitTest` 查询中执行关闭；同一点击可传到底层控件。

滑动方向支持物理上下左右任意组合、四向、横向、纵向、禁用和跟随位置的自动方向。居中预设可显式开启拖拽。关闭阈值默认 100 点，快滑使用 0.15 秒速度投影；方向在开始时锁定，滑动不足、取消、反向回拉或业务拦截时回弹，成功则沿手指方向退出并保留原入场动画配置。横竖滚动内容在对应边界才交出手势，边界判断依据原始触摸视图。

修复了关闭拦截回调里程序主动关闭可能被回弹覆盖、动画中背景配置未更新的问题。真实 UI 验证还定位到 iOS 26 的整页返回手势会接管被禁止的右滑，导致底层页面返回；现于非穿透弹窗展示期间暂停宿主导航返回手势，最后一个弹窗关闭后按原状态恢复，穿透模式保留底层导航行为。

- iOS 15 部署目标 / Swift 6 严格模式类型检查通过；设备签名构建通过。
- Duo / iOS 27.1 核心测试 **43/43 通过**；包含原有布局、生命周期、玻璃、标题，以及新增的关闭、导航手势回归。
- Duo / iOS 27.1 和 iPhone 13 Pro / iOS 26 的实际触摸 UI 测试均 **3/3 通过**：四向拖拽、方向限制与高阈值、隐藏遮罩外部关闭、拦截外部点击、穿透不关闭、同一次穿透点击既更新底层计数又关闭弹窗。
- 最终各测试命令均退出码 0 / `TEST SUCCEEDED`；日志未发现约束冲突或生命周期异常。
- 最终证据：`interaction-core-verified.log` / `InteractionCoreVerified.xcresult`、`interaction-duo-verified.log` / `InteractionDuoVerified.xcresult`、`interaction-phone-verified.log` / `InteractionPhoneVerified.xcresult`。方向限制前后截图已导出核对。
- Demo 导航栏新增“关闭交互”，提供各开关、允许方向和 50/100/200 点距离选项；“交互方案”可快速选择组合。原项目未改动，旧 `.config` 调用仍需按迁移表改为新 `.configuration`。
- 该最终版本已覆盖安装至用户的 iPhone 13 Pro / iOS 26.5，并成功启动。安装、启动命令均退出码 0。本轮没有重跑此前的 iOS 27.1 连续输入后点击问题，相关历史限制仍保留。

## Alert 外部间距与大屏最大尺寸

`BoneAlertView` 的确认与输入构造方法默认改为左右各 32 点外部间距，面板最大宽高 420 × 600 点。新增 `horizontalMargin` 与 `maximumSize`，直接映射到底层 layout margins 和 maximumWidth/maximumHeight，可在显示期间修改。上限在 iPad、Duo 和其他窗口尺寸下统一生效；面板仍按安全区、键盘、折叠区域及小窗口继续缩小。通用 `.centerDialog`、操作列表和 24 点内部边距保持原默认值。整份覆盖配置会重置对应布局值。

- iOS 15 / Swift 6 类型检查及设备签名构建通过；20 组使用手册 Swift 示例和文档链接校验通过。
- 完整核心测试 **47/47 通过**，新增 4 项覆盖两种 Alert 默认值、大屏和窄窗口尺寸裁剪、实时修改、长内容滚动和折叠区域限制。证据：`alert-sizing-core.log` / `AlertSizingCore.xcresult`。
- iPhone 13 Pro / iOS 26 尺寸用例 **1/1 通过**；iPad Pro 11-inch / iOS 26 尺寸用例 **1/1 通过**。验证默认 32 / 420×600、自定义 48 / 360×460、默认长内容上限，以及滚动到取消按钮关闭。证据：`alert-sizing-phone-final.log` / `AlertSizingPhoneFinal.xcresult`、`alert-sizing-pad-final.log` / `AlertSizingPadFinal.xcresult`。
- 初轮 iPad 尺寸用例在首次展示前失败，之后加入明确的列表/行可点击等待与关闭完成等待再复测通过。初轮 iPad 标题布局用例通过；手机标题用例的布局断言通过，但取消后的点击等待与后续列表点击失败，仍保留在 `AlertSizingPhoneUI.xcresult`，不算作本轮完整 UI 全通过。
- 已核对手机与 iPad 的尺寸截图；Demo 增加“自定义 Alert 尺寸”和“Alert 长内容上限”场景。默认尺寸是上限，不意味着所有短内容都固定为 420×600 点。
- 已覆盖安装至用户 iPhone 13 Pro / iOS 26.5；安装成功，自动启动因手机锁屏被拒绝，需解锁后手动打开 Demo。

## Alert 默认左右双按钮

`BoneAlertView` 的确认与输入预设改为默认等宽横排：LTR 环境取消在左、确认在右，按钮间距 12 点。新增独立的 `buttonLayout`（`.automatic` / `.horizontal` / `.vertical`），默认自动模式在窄空间、长按钮标题或辅助功能大字号下回退为竖排；竖排确认在上、取消在下。排列在测量前确定，运行时切换会重新计算高度；操作列表维持原竖排。

- iOS 15 / Swift 6 类型检查、设备签名构建、21 组手册 Swift 示例及文档链接检查通过。
- 核心测试 **52/52 通过**，新增 5 项覆盖确认与输入默认横排、窄空间和长文案回退、显示期间切换、辅助功能字号及折叠后恢复排列。既有内部边距断言同步为双按钮行。
- iPhone 13 Pro / iOS 26 按钮 UI 用例 **1/1 通过**；iPad Pro 11-inch / iOS 26 按钮 UI 用例 **1/1 通过**。均验证默认横排、手动竖排、窄空间自动竖排、等宽和 12 点间距，以及实际点击关闭。
- iPad 首轮在测试启动前超时，未产生布局断言结果；重启专用模拟器后以已编译测试包复测通过。最终证据：`alert-button-core.log` / `AlertButtonCore.xcresult`、`alert-button-phone.log` / `AlertButtonPhone.xcresult`、`alert-button-pad-final.log` / `AlertButtonPadFinal.xcresult`。
- 已核对手机默认左右按钮与竖排回退截图，Demo 增加“Alert 竖排按钮”和“Alert 窄空间”场景。新版本已覆盖安装至用户 iPhone 13 Pro / iOS 26.5；自动启动因锁屏被拒绝，需解锁后手动打开。

## 统一内容样式与 18 点粗体标题

确认框、输入框和操作列表新增统一 `PopoverContentStyle`，由 `configuration.contentStyle` 保存。标题基础字体改为 `UIFont.boldSystemFont(ofSize: 18)`，正文保留 17 点；标题/正文 `UIFont`、颜色、对齐、内容内边距、标题与内容间距、内容与按钮间距、按钮间距及按钮内边距统一开放。按钮和输入字体也可配置。原 `titleAlignment` / Alert `buttonLayout` 便利入口现在直接读写同一份样式，整份替换 `configuration` 会同时替换内容样式。

- 最终源码通过 **Swift 6 严格模式 / iOS 15 部署目标**检查；作为外部调用方编译的 **22 组手册 Swift 示例**及本地文档链接检查通过。iOS 15 仍仅完成编译验证，没有对应运行时实测。
- Duo / iOS 27.1 完整核心测试 **59/59 通过**。新增 7 项覆盖三类预设默认字体、自定义字体/颜色/对齐和实际内部距离、操作列表图标和角色保留、运行时更新及输入内容/选区/焦点保留、Dynamic Type 多次放大/恢复与固定字号、字体及内边距影响按钮自动排列、便利入口与配置替换行为。
- 修正多行按钮的 `intrinsicContentSize` 受现有换行宽度影响的问题：自动选轴使用不受宽度约束的 `sizeThatFits`。系统字号更新在子控件完成 trait 传播后刷新样式并重新测量，避免面板保留旧字体的高度；对应回归测试完成多次往返验证。
- iPhone 13 Pro / iOS 26 UI **3/3 通过**，iPad Pro 11-inch / iOS 26 UI **3/3 通过**；本轮均首次执行通过，没有重启复测。覆盖默认等宽横排、手动与窄空间竖排、自定义字体与全部段落距离，以及弹窗内切换大字号/宽间距并恢复默认后的尺寸与实际点击。
- 最终日志未发现严重 Auto Layout 约束冲突。Xcode 有设备 build 版本解析、PointerUI / debugger 元数据等非致命环境信息；测试命令均返回 0 / `TEST SUCCEEDED`。
- 已导出手机和平板各 6 张截图，并核对默认 Alert、自定义样式及操作列表切换前后：文字和按钮完整显示，内边距及玻璃轮廓正常。Demo 现有 14 个场景，新增“自定义字体与间距”和“即时调整内容样式”。
- 最终设备签名构建通过；已覆盖安装至用户 iPhone 13 Pro / iOS 26.5，**安装及自动启动均成功**，bundle ID 为 `dev.bone.BonePopoverDemo`。
- 最终证据：`content-style-core-verified.log` / `ContentStyleCoreVerified.xcresult`、`content-style-phone.log` / `ContentStylePhone.xcresult`、`content-style-pad.log` / `ContentStylePad.xcresult`，以及对应 `content-style-phone-screens` / `content-style-pad-screens` 截图目录。历史的 iOS 27.1 连续输入后点击问题与实体 Duo 全姿态限制仍按前文记录，本轮未扩展复测范围。

## 独立 Window、导航与 Scene 隔离

按已批准方案完成独立窗口模式：`show(from:)` 保留页面承载，`show(over:)` 绑定源业务 Window，`show(in:)` 使用指定 Scene，`show()` / `show(isNav:)` 仅自动选择唯一前台活动 Scene。所有入口返回 Bool，准备阶段失败或取消会回滚；窗口选项通过 `configuration.window` 保存创建快照，字体、材质、布局和触摸配置继续实时刷新。默认层级 `.alert - 1`，支持固定/自动叠加、接管并恢复/保留 key、普通/导航容器。

新增六个窗口承载文件，UIKit 状态保持 `@MainActor`，会话按 Scene 隔离，使用每次展示 UUID 防止旧动画/通知影响重显。完成回调在资源移除和窗口恢复后执行，重复关闭 completion 各一次；真实穿透观察不取消底层触摸。Demo 增加第 15 个场景“独立 Window 与多 Scene”，XcodeGen 已重新生成工程。原 App 和旧包保持只读，未初始化 Git、提交或发布。

### 最终检查结果

以下为同一实现的分批验证，表中重复覆盖不相加为单次测试总数；日志及 xcresult 均保留于本会话 scratch，随会话清理。

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| Swift 6 严格模式，arm64 / iOS 15 simulator module | 通过；tools version 5.9、SDK 最低 iOS 15 保持 | 最终 swiftc emit-module / 外部 typecheck 命令 |
| 外部调用方示例与本地链接 | 使用手册 22 组 + Window 文档 2 组通过；本地链接通过 | `doc-examples/UsageGuideExamples.swift`、`WindowExamples.swift` |
| Duo / iOS 27.1 完整核心回归 | **59/59 通过** | `window-core-verified.log` / `WindowCoreVerified.xcresult` |
| iPad / iOS 26 完整窗口托管测试 | **22/22 通过**，含真实双 Scene 销毁隔离和新增窗口布局回归 | `window-pad-acceptance-host.log` / `WindowPadHostAcceptance.xcresult` |
| Duo 窗口托管回归 | 原 21 项为 **20 通过、1 跳过**；新增布局另 **1/1 通过** | `window-duo-recheck-host.log` / `WindowHostedDuoRecheck.xcresult`、`window-duo-acceptance-host.log` / `WindowDuoHostAcceptance.xcresult` |
| iPhone 13 Pro / iOS 26 UI | **9/9 通过**：原 6 项 Window + 默认按钮 1 项 + 内容样式 2 项 | `window-phone-verified.log` / `WindowPhoneVerified.xcresult` |
| iPad Window UI | 原 **6/6 通过**；拆分后的导航/Scene 用例再 **2/2 通过** | `window-pad-verified.log` / `WindowPadVerified.xcresult`、`window-pad-acceptance-ui.log` / `WindowPadNavigationAcceptance.xcresult` |
| iPad 默认按钮与内容样式 UI | 修正启动入口后 **3/3 通过** | `window-pad-recheck-ui.log` / `WindowPadStyleRecheck.xcresult` |
| Duo 相关 Window UI | 输入、固定/自动层级与乱序关闭、导航入口共 **3 项通过**；独立 Scene 销毁用例 **1 项明确跳过** | 前两项见 `window-duo-verified.log`；导航/Scene 最终见 `window-duo-acceptance-ui.log` / `WindowDuoNavigationAcceptance.xcresult` |
| iPhone / iPad / Duo 独立 Window 布局 | 三端新增布局用例均 **1/1 通过**；iPad 已包含在上述 22 项中 | `window-phone-acceptance-host.log` / `WindowPhoneHostAcceptance.xcresult`，以及两端 `Window*HostAcceptance.xcresult` |
| 最终 iPhone 设备签名构建 | **BUILD SUCCEEDED**，Apple Development，team 2PX9496FD6 | `window-device-delivery-build.log` |
| 用户 iPhone 13 Pro / iOS 26.5 | **覆盖安装成功、自动启动成功**，bundle `dev.bone.BonePopoverDemo` | `window-device-install.json`、`window-device-launch.json` 均 outcome success |

窗口托管测试在 `Tests/BonePopoverWindowTests`，由 Demo 的 `BonePopoverWindowTests` scheme 提供真实 `UIWindowScene`；普通包测试 runner 没有业务 Scene，因此 Scene 相关用例不放入 59 项核心测试。新增布局用例在真实独立 Window 中注入宽/窄宿主 bounds、横竖保留区域，验证不重叠和尺寸回退，再以有输入焦点的窗口验证键盘 frame 通知、隐藏恢复及经典/玻璃材质切换。新增用例首轮未建立输入焦点，键盘通知被正常过滤；补齐前置条件后，三端均通过。

### 已定位并回归的问题

- 最初两个弱引用 Window 释放断言失败。`leaks --traceTree` 定位到 UIKit 的 `TUIKeyboardTrackingCoordinator.trackingWindows` 持有已经移除的窗口。独立窗口不再创建/读取 `UIKeyboardLayoutGuide`，改用屏幕 frame 通知转换到宿主坐标；页面模式保留键盘指南。两个实际窗口释放回归及最终托管套件均通过，保留 `window-references.log`、`WindowNotificationKeyboardFix.xcresult` 作为定位证据。
- 初轮 iPad 固定低层弹窗没有同步建立宿主。调整为显示前加载根控制器并主动刷新 Window 布局后，手机、iPad、Duo 的固定/自动层级与乱序关闭用例通过。
- 初轮源业务窗口关闭后的 Scene 总窗口计数受 UIKit 的 `UITextEffectsWindow` 影响。Demo 改为统计自身 `window-*` 窗口，并另外显示 Scene 全部窗口类型；托管测试继续检查真实弱引用释放、空根控制器及观察器移除，未用隐藏或计数替代释放断言。
- iPad 首次综合 UI 的 9 项中 7 通过、2 在等待 `demo-list` 时失败，尚未进入按钮/字体断言。原因是上次窗口演示页被 Scene 恢复。原页面 UI 用例使用 `--demo-home` 明确入口，3 项复测通过。
- Duo 导航最初在返回列表后滚动越过目标行。改为按行的实际位置小步滚动后，push/pop、整栈关闭、显式 Scene、自动 Window 和 `isNav` 入口通过；Scene 激活与销毁拆为独立用例，避免把系统拒绝销毁混为导航失败。
- 重入审查修正了消失回调立即重显、`shouldDismiss` 内关闭重显、隐藏通知创建新 key Window、`addChild` 准备阶段关闭、导航根真正移除及等层级上层窗口被误观察等边界；6 项对应回归通过。

### Scene 与运行边界

iPad 托管测试实际创建第二 Scene，在两个 Scene 的源 Window 上各展示一个弹窗，再请求销毁第二 Scene；其弹窗与会话被清理，第一个 Scene 的弹窗仍为 presented。iPad UI 也实际激活/关闭第二 Scene，并返回原页面继续点击。该结果验证两个已连接真实 Scene 的归属与清理隔离；**没有单独完成两个 Scene 同时 foregroundActive 的所有多任务组合验收**。

Duo 的 `supportsMultipleScenes` 为 true，实际第二 Scene 激活成功，但主动销毁返回 `SBApplicationSupportService` code 1：`This functionality is not supported for this device idiom.` 因此托管和独立 UI 销毁用例明确记录为跳过，不能算作 Duo 销毁成功。iPhone 本轮 9 项 UI 的原合并用例读取到 unsupported 后提前返回；未把该分支算作真实多 Scene 通过，新拆分的 Scene UI 用例在该 iPhone 上未另跑。

最终真实 UI 日志没有 Auto Layout 冲突或不平衡生命周期警告。托管测试在同一调用栈快速显示/隐藏 UIWindow 时仍记录 `Unbalanced calls to begin/end appearance transitions`；原生 UIWindow 对照也能复现，保留 `window-raw-lifetime.log`。不能据此声称所有运行路径完全没有生命周期警告。部分日志另有 Xcode 设备 build 版本解析、AppIntents 元数据及 RTI 输入会话的非致命信息。

iOS 15 仍仅完成编译支持验证；实体 Duo 全姿态、实际 iPadOS 全部窄分屏组合及完整人工辅助功能巡检未完成。历史 iOS 27.1 页面模式连续输入后点击问题保留，本轮没有用独立 Window 用例代替该场景。排队、优先级、替换和唯一调度仍属于 App 业务能力，不在本轮实现中。入口、创建快照及所有权说明见 [独立 Window 模式](WindowPresentation.md)。
