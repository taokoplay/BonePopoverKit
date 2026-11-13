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

## Toast 顶部长条、底部长条与中间方块

新增 `BoneToastView`，默认 2 秒后自动关闭，支持 `.top` / `.bottom` / `.center`、可选图标及显示期间更新文字、图标、时长和统一样式。顶部/底部最大宽度 560 点，居中方块从 160 点起随内容增大，默认最大 280 × 280 点；小区域继续缩小，超长内容由内部滚动承载。默认无遮罩、允许外部触摸穿透；独立 Window 保留当前 key 与输入焦点。计时使用 MainActor Task，关闭时取消，并用每次展示的标识隔离旧计时。非模态展示使用 announcement，避免 screenChanged 抢走辅助功能焦点。

- Swift 6 严格模式 / iOS 15 simulator 目标类型检查通过；单独生成 module 后，Toast 使用手册示例作为外部调用方编译通过。
- iOS 27.1 完整核心回归 **66/66 通过**，包括新增 7 项：三种位置和实际图文布局、无背景与触摸穿透、动态文字/图标/样式、小区域与长内容滚动、展示完成后计时、取消/重显/重设计时、禁用及极大时长、宿主移除与释放。
- iOS 27.1 独立 Window 新增用例 **1/1 通过**：输入状态下展示 Toast，验证 key 与 first responder 保留、超时自动移除、窗口清空及会话释放。
- iPhone 13 Pro / iOS 26 UI **2/2 通过**，覆盖三种形态、顶部仍显示时真实点击底层切换到底部、自动关闭与中心方块比例；三张最终截图已核对，UI 日志无约束冲突。
- 首轮手机 UI 的 2 项均在读取短时 Toast 的 ready 标记时失败；自动化等待和跨进程查询可能耗尽 Demo 的 3 秒停留时间。测试通过环境变量 `BONE_TOAST_DEMO_DURATION=10` 延长可观察窗口后复测通过，不改变组件默认 2 秒或普通 Demo 的 3 秒行为。实际计时与取消语义仍由核心测试和 Window 托管测试独立覆盖。
- Demo 增加第 16～18 个场景，保留已有场景编号；XcodeGen 工程已同步。尚未进行真机安装或完整人工 VoiceOver 验收；iOS 15 仅完成编译验证。
- 本会话 scratch 证据：`toast-core.log` / `ToastCore.xcresult`、`toast-window.log` / `ToastWindow.xcresult`、`toast-phone-verified.log` / `ToastPhoneVerified.xcresult`；首轮失败保留于 `ToastPhoneUI.xcresult`，最终手机截图在 `toast-phone-screens`。
- 平板深色 / XL 字号补充验收未完成，未计为通过：旧 `BonePopoverKit iPad Sizing QA` 的 data 目录缺失，创建临时 iPad 后测试宿主持续未启动，截图命令也在 60 秒后超时；最终 runner 安装/启动报 Mach -308，未进入用例。临时模拟器已关闭并删除。`toast-pad-dark.log` / `ToastPadDark.xcresult` 保留失败证据，本轮没有用核心几何测试替代这项真实平板 UI 验收。

## Toast 成功、失败、提示与加载中类型

新增 `BoneToastView.ToastType`：`.success`、`.failure`、`.info`、`.loading`，可与三种布局组合使用，默认类型为 `.info`。成功/失败/提示使用绿色勾选、红色叉号、蓝色信息图标，加载中使用原生进度圈。`duration` 对四种类型统一默认 2 秒，可传入任意正秒数，0 持续显示；显示期间修改时长或类型会重新计时。加载动画随展示、关闭、类型切换及复用自动开始/停止，自定义图标在非加载类型继续生效。

- Swift 6 严格模式 / iOS 15 simulator 目标类型检查通过；两组更新后的 Toast 文档示例和一组旧参数标签调用作为外部 client 编译通过；文档本地链接及 `git diff --check` 通过。
- Duo / iOS 27.1 完整核心测试 **70/70 通过**，其中 Toast **11/11**。新增 4 项覆盖四类型 × 三布局的指示器、加载动画开始/停止/复用、自定义图标与类型切换、四种类型实际按默认 2 秒关闭、类型切换后的计时重启及自定义时长。
- iPhone 13 Pro / iOS 26 原布局 UI **2/2 通过**；新增菜单 UI 单独执行 **1/1 通过**。实际操作持续显示 → 失败 → 提示 → 加载中 → 成功 → 1 秒自动关闭，验证辅助功能状态值、Toast 持续存在和最后自动移除，并保存四种类型截图。Demo “Toast”菜单提供类型以及 1 / 2 / 3 / 5 秒或持续显示，默认时长同步为 2 秒。
- 首轮 UI 未枚举新增方法，按完整方法名执行时仍为 0 tests，未将此记录算作新增用例通过。确认方法已编译、带 Objective-C thunk，且已安装测试二进制与构建产物相同；终止并卸载专用 QA 模拟器中的测试运行器，再由 Xcode 安装后，新方法实际执行且通过。测试方法未改写或合并。
- 证据：`toast-types-core.log` / `ToastTypesCore.xcresult`、`toast-types-phone-ui.log` / `ToastTypesPhoneUI.xcresult`、`toast-types-menu-fresh.log` / `ToastTypesMenuFresh.xcresult`，四类型截图位于 `toast-types-menu-screens`。本轮未扩展平板、真机或完整人工辅助功能验收。

## Sheet 默认样式按阅读器默认调整

对照 ParsingBook（小说阅读器）的定制 `BonePopoverView` 基类与其 sheet 子类：圆角 16 点、`.sheet` 形态仅顶部两角、全宽贴底无外部留白、默认无背景遮罩（`isShowBackgroud = false`）、无抓手、纯色表面、基类背景为 `systemBackground`、定制动画时长 0.15 秒。`.bottomSheet` 预设按上述值重设；`PopoverAppearance` 新增 `maskedCorners`（默认四角，行为不变），表面视图将其同步到前景层、效果层与阴影路径。iOS 26 玻璃的非对称圆角改用 `UICornerConfiguration.corners(topLeftRadius:...)` 逐角配置（不圆的角传 nil），保持玻璃原生轮廓；iOS 25 及更早版本继续使用 layer 圆角加 maskedCorners。`BonePopoverView(contentView:)` 默认使用 `.bottomSheet`，因此自定义内容底部面板同步获得该默认样式；其他预设与 `PopoverConfiguration()` 默认值不变。

- iPhone Duo（8E80DEE0，iOS 27.1）核心测试 **72 项中 71 通过、1 项超时**：`testDynamicTypeChangesScaleFromBaseFontsAndCanBeDisabled` 在 traits 传播等待 3 秒内未完成（XCTWaiter 超时）；该用例使用未改动的 `.centerDialog` 预设，单测重跑 **1/1 通过**（10.7 秒），判定为模拟器时序抖动而非本次改动引入。两项新增测试（`.bottomSheet` 预设默认值、非对称圆角应用）均通过。日志无 Auto Layout 约束冲突。
- 补充阅读器头部关闭按钮：操作列表标题左侧新增向下箭头关闭按钮（`closeButton`，40 × 40 点圆形命中区，辅助功能标签"关闭"、标识 `popover-close`），点击关闭弹窗；`showsCloseButton = false` 可隐藏，加载后修改实时生效。对应阅读器各 sheet 子类 `backButton.pin.left().top().width(40)` 的头部结构。箭头使用 12 点 medium 的 SF Symbol `chevron.down`；iOS 26+ 通过 `UIButton.Configuration.glass()`（capsule）渲染液态玻璃圆圈按钮，早期系统回退为标题色 8% 透明度圆圈。图标颜色跟随 `contentStyle.titleColor`。Demo"外观"选"自动"时不再整体覆盖预设外观，让 sheet 默认样式生效。核心回归 **73/73 通过**（新增关闭按钮行为 1 项，2 项纯内容样式度量用例改为 `showsCloseButton = false` 保持原语义）；UI 测试 `testActionSheetUsesReaderDefaultSheetLayout` 实际点击关闭按钮关闭并截图通过。截图：`Screenshots/iPhoneDuo/action-sheet-reader-default.png`。该轮结束时对 `.bottomSheet` 追加的标题居中与隐藏态约束问题见下一节，本轮修复后重新验证。
- 本会话 scratch 证据：`sheet-reader-core.log`、`dynamic-retest.log`、`sheet-close-core.log`、`sheet-reader-ui.log`。
- 阅读器侧的浅色主题强制覆盖（`userInterfaceStyleOverride` 跟随 BoneThemeManager）属于应用层主题逻辑，未纳入 SDK 默认。

## Sheet 阅读器默认样式收尾（标题居中与头部约束）

上一轮在 12:47 跑完 73/73 与 UI 测试后，又对 `.bottomSheet` 追加了 `contentStyle.titleAlignment = .center`（对照 ParsingBook 各 sheet 子类标题居中），但没有重跑测试；同时头部隐藏逻辑存在真实布局缺陷。本轮补齐：

1. 基线复现：Duo（8E80DEE0，iOS 27.1）核心测试 **73 项中 2 项失败**——`testDefaultTitleIs18PointBoldInAllPresets`、`testConveniencePropertiesShareStyleAndFullConfigurationReplacesIt` 仍断言所有预设标题左对齐。按阅读器参照把预期改为「`.bottomSheet` 居中、确认框与输入框左对齐」，而不是放宽断言。
2. 头部约束缺陷：`rebuildHeaderRow()` 原先 `closeButton.removeFromSuperview()` 后再 `addSubview`，UIKit 移除子视图时连带移除安装在 `headerRow` 上的 `closeButton.leading` / `centerY` 约束，标题行随之塌陷。临时打印实测：`titleLabel.frame = (270.33, 0, 71.67, 21.67)`、`closeButton.frame = (222.33, 0, 40, 40)`、`headerRow` 高 21.67，左对齐标题退回固有宽度并贴右。改为 `closeButton.isHidden = !showsCloseButton`，不再增删子视图；隐藏态不参与命中测试与辅助功能。
3. 前置约束未跟随状态：`applyTitleLeadingConstraint()` 未考虑 `showsCloseButton`，且 `applyContentStyle()` 没有重新启用约束，显示期间切换标题对齐会把居中标题推偏。现在两处都在样式刷新时重算。
4. 新增 `testSheetTitleLeadingFollowsCloseButtonAndAlignment`：左对齐标题 minX = 72（24 内容边距 + 40 按钮 + 8 间距）、隐藏按钮后回到 24、切到居中后横贯整行（24 至宽度 − 24）；原「隐藏后无父视图」断言改为 `isHidden`。
5. 文档：README / UsageGuide 补 `maskedCorners`、关闭按钮、`.bottomSheet` 标题居中与 560 点宽度上限（此前写「全宽」与实现不符）；UsageGuide 的「40 × 44 命中区」更正为「40 × 40」。

- 核心回归 **74/74 通过**（`core-full.log`；失败基线 `core-baseline.log`），无 Auto Layout 冲突告警。
- UI 测试 `testActionSheetUsesReaderDefaultSheetLayout` **1/1 通过**（`sheet-reader-ui7.log` / `SheetReaderUI7.xcresult`），截图重采集为 `Screenshots/iPhoneDuo/action-sheet-reader-default.png`（1398 × 2034）。
- 该 UI 用例的宽度断言改用窗口坐标：`app.frame` 固定按竖屏返回，横屏或折叠姿态下与元素坐标不一致。Duo 的系统 division/occlusion 保留区会让面板只填满所在侧栏（本轮实测窗口 466 × 678 点、面板 382 点宽、底缘 312.7 + 331.3），因此断言改为「贴底 + 填满所在可用区（受 560 点上限）+ 关闭按钮可点」，不再断言等于整窗宽度。截图中的标题为左对齐，是因为 Demo「标题对齐」菜单默认左对齐覆盖了预设；SDK 默认居中。
- 环境记录：本轮首次 UI 运行（`sheet-reader-ui2.log`）以 `Timed out while preparing execution worker` 失败并挂起 xcodebuild，终止进程并重启 Duo 模拟器后恢复；`sheet-reader-ui3` / `ui4` 记录了横屏 + 保留区姿态下的定位过程。
- 未完成：实体 Duo 全姿态的人工验收不在本轮范围；模拟器上的浅色外观与 iPad 平板结果见下一节。

## Sheet 样式补充验证：浅色外观与 iPad 宽布局

- Duo（8E80DEE0，iOS 27.1）切到系统浅色外观（`simctl ui … appearance light`）重跑 `testActionSheetUsesReaderDefaultSheetLayout`，**1/1 通过**（`sheet-reader-light.log` / `SheetReaderLight.xcresult`）。截图 `Screenshots/iPhoneDuo/action-sheet-reader-default-light.png`（1398 × 2034）确认：面板为纯白 `systemBackground`、底部两角为直角、底层列表保持 `secondarySystemBackground` 亮度（无遮罩）。验证完恢复模拟器原来的深色外观。
- iPad Pro 11-inch (M4) 模拟器（99C156C5，iOS 27.1）同一用例 **1/1 通过**（`sheet-reader-pad.log` / `SheetReaderPad.xcresult`）：面板宽度断言 `≤ 561` 通过，说明 560 点上限在 834 点宽的平板上生效（未封顶会是整窗宽度），底缘贴窗口底部，关闭按钮可点。
- 结论：`.bottomSheet` 的「贴底、宽度取所在可用区、560 点上限」在手机与平板都成立；「严格整窗满宽」只在小屏手机成立，平板按 560 点居中，该差异已写入 README 与 UsageGuide，不在代码层改变宽度策略。

## Demo 呈现与真机安装

- Demo「标题对齐」菜单新增「预设默认」（初始选中，`selectedTitleAlignment` 改为可选）：只有用户主动选过左/中/右才覆盖内置标题对齐，因此「底部操作列表」场景直接呈现 `.bottomSheet` 的居中标题与左侧关闭按钮。告警与输入框预设默认仍是左对齐，行为不变。
- 该调整让 `testActionSheetUsesReaderDefaultSheetLayout` 首次以居中标题运行，暴露真实缺陷：居中标题横贯整行后覆盖关闭按钮位置，XCUITest 判定按钮不可点（`Error: -[...] : XCTAssertTrue failed - 标题左侧应有向下箭头关闭按钮`）。修复为标题先加入、关闭按钮后加入以取得更高层级，并在 `testActionSheetCloseButtonDismissesAndCanBeHidden` 中新增 subview 顺序断言（按钮必须在标题之上）。修复后核心 **74/74 通过**（`core-zorder.log`），`testActionSheetUsesReaderDefaultSheetLayout` 与 `testTitleAlignmentAndFullWidthButtons` **2/2 通过**（`demo-align2.log`）；修复前的失败记录保留在 `demo-align.log`。
- 真机：iPhone 13 Pro「Yu iPhone 13Pro」（iOS 26.5，UDID `00008110-000620DC0AA2801E`），Team `2PX9496FD6` 自动签名（profile 为 `iOS Team Provisioning Profile: *`，含该设备），`xcodebuild build` 生成 `Debug-iphoneos/BonePopoverDemo.app` → `devicectl install` 安装成功 → `devicectl process launch` 前台启动成功（进程 pid 6140）。首次启动被系统以 `Locked` 拒绝，解锁手机后重试成功。
- 真机验证范围：仅确认新构建可安装并启动，未做真机上的逐场景人工点检。

## 阅读器旧弹层可配置项补齐（不设置即默认）

对照 ParsingBook `Custom/BonePopoverView`，把“阅读器里写死、SDK 也没有入口”的值补成可选配置，逐项对照见 [阅读器对照](ReaderParity.md)。

- `BoneAlertView.confirmTitle` / `cancelTitle`：默认 `nil` → “确认”“取消”；空字符串视为未配置；赋值后立即改写按钮并重新测量，宿主直接修改 `button.configuration?.title` 的旧写法不被样式刷新覆盖。
- `configuration.interfaceStyle`：默认 `.unspecified` 跟随宿主与系统；`.light` / `.dark` 同时作用于 `PopoverHostView` 与弹层自身，设回 `.unspecified` 恢复继承。
- `contentStyle.closeButtonImage` / `.closeButtonSize`：默认 `nil` / 40 点；样式刷新不再用内置箭头覆盖宿主自定义图标，尺寸变化同步宽高约束。
- `PopoverAnimation.scale(_:duration:dampingRatio:)`：比例夹在 0...1，`.scale` 仍等价 0.92 / 0.25 秒。
- 过程记录：首版每次样式刷新回写默认标题，导致 `testAutomaticUsesColumnForNarrowSpaceAndLongButtonTitles` 与 `testLiveStyleChangeRemeasuresAndPreservesInputFocusTextAndButtonContent` 2 项回归（`core-parity.log`）；改为按配置快照比较后修复。
- 核心回归 **79/79 通过**（`core-parity2.log`，新增 5 项见 `PopoverReaderParityTests.swift`；新增用例首轮 `parity.log` 5/5）。
- 未采纳的部分（队列优先级、业务列表高度、图标 bundle、状态栏/方向锁）与理由见 [阅读器对照](ReaderParity.md) 第 3 节。

## P0 复核：iOS 27.1 连续输入后列表不可点击

历史记录（见「材质外观与轮廓」轮次）：Duo / iOS 27.1 在输入框确认后弹窗已移除，但后续列表项不可点击，失败层级里存在额外全屏空窗口且持有方未确认。

- 本轮在同一设备（iPhone Duo `8E80DEE0`，iOS 27.1）用既有用例 `testConfirmationInputAndLiveStyleSwitch` 复测 **1/1 通过**（`input-tap-27.log` / `InputTap27.xcresult`）。
- 按“前置 Window 用例可能留下窗口”的线索，再连跑 `PopoverWindowUITests/testTwoBusinessWindowsFixedAndAutomaticStackingWithOutOfOrderClose` + 上述用例，**2/2 通过**（`input-after-window.log`），未出现额外窗口导致的点击失败。
- 结论：当前版本无法复现该问题。不能据此证明历史根因已修（期间有多次关闭清理与宿主失效改动），也不再把它列为开放阻塞；改为“历史记录 + 由该用例持续覆盖”。若再次出现，按失败层级中的窗口持有方继续定位。

## 内置文案收口（P0-3 / P1-4）

- 文案按组件拆分，不进入 `PopoverConfiguration`：`BoneAlertView.confirmTitle/cancelTitle`、`BoneActionSheetView.cancelTitle/closeAccessibilityLabel`、`BoneToastView.typeDescriptions`、`BonePopoverView.backdropAccessibilityLabel`；默认全部保持原文字（“确认”“取消”“关闭”、`NSLocalizedString("Dismiss")`、Toast 四类中文 key）。
- 操作列表：`sheet.cancelTitle` 支持运行期读写，优先级为自身属性 → 初始化参数 → “取消”；关闭按钮辅助功能标签走 `sheet.closeAccessibilityLabel`。
- 遮罩标签走 `popover.backdropAccessibilityLabel`；Toast 类型朗读描述走 `toast.typeDescriptions`，赋值后立即刷新辅助功能值。
- 改写策略：只在属性赋值或视图加载时写按钮，样式刷新不回写文案，宿主直接修改 `button.configuration?.title` 的旧行为继续保留。
- 核心回归 **81/81 通过**（`core-strings.log`；`PopoverReaderParityTests` 扩到 7 项，新增操作列表文案与 Toast/遮罩标签 2 项）。
- UI 复测：Demo `testActionSheetUsesReaderDefaultSheetLayout` 在 Duo/iOS 27.1 通过；`PopoverToastUITests/testTypesAndDurationCanChangeWhileVisible`（覆盖 Toast 类型描述朗读值）在 **iPhone 13 Pro / iOS 26.0** 通过（`ui-toast-26.log`），在同机 Duo / iOS 27.1 上两次运行分别失败于导航栏 `toast-options` 元素查找与朗读值等待（失败位置不同，`ui-strings.log` / `ui-toast-retry.log`），暂判为模拟器负载抖动，不记为通过；字符串行为以 7 项单元测试为准。

## 操作列表增量 API（addButton / addAction）

- `BoneActionSheetView.init(title:message:actions:cancelTitle:)` 的 `actions` 改为默认空数组，因此可以只给标题/正文建面板；新增 `addButton(_:image:role:dismissesPopover:handler:)` 与 `addAction(_:)`，都返回对应 `UIButton`。
- 新按钮插入到取消按钮之前（`insertActionButton` 按取消按钮索引定位），添加后立即 `applyContentStyle()` 并 `invalidatePopoverLayout()`，已展示时高度即时刷新；视图未加载时先 `loadViewIfNeeded()`，不会重复创建按钮。
- 按钮构建抽成 `makeActionButton(for:)`，初始化路径与增量路径共用同一份样式、图标、destructive 着色和关闭语义。
- 测试：新增 `PopoverActionSheetBuilderTests` 2 项（无 actions 创建 + 竖排顺序/字体、`dismissesPopover` 与先关闭再回调）；核心回归 **83/83 通过**（`core-builder.log`）。
- Demo 场景 2 改为增量写法；UI 用例 `testActionSheetUsesReaderDefaultSheetLayout` **1/1 通过**（`ui-builder.log`）。

## Demo 首页布局与 App 图标

- `DemoViewController` 改为 `UIViewController`：顶部常驻控制条（外观/动画分段控件 `style-control` / `motion-control`）、中间分组场景列表（常用弹窗 0-4、布局与保留区域 5-11、内容样式 12-13、独立窗口 14、Toast 15-17，每行带一句话说明）、底部常驻结果条（`demo-result`）。`demo-list`、`scene-N`、导航栏 `title-alignment` / `interaction-demo` / `toast-options` 均保持不变。
- 新增 AppIcon（1024×1024，无 alpha）：深靛蓝→紫罗兰渐变、半透明玻璃底部面板、关闭按钮与列表行占位；接入 `Assets.xcassets`，XcodeGen 工程设置 `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`；生成脚本 `Examples/BonePopoverDemo/Tools/AppIconRenderer.swift`。
- 测试：`PopoverDemoUITests` **4/4**、`PopoverAlertButtonsUITests` **1/1**、`PopoverContentStyleUITests` **3/3** 通过（`ui-demo-layout.log`、`ui-content-style2.log`）。
- 同步修正两处旧问题：`testLiveStyleChangesAndRestoresTheActionListLayout` 的标题左边距未计入关闭按钮（40 + 8），改为 `padding + 48`；`openScene` 的滚动次数 5 → 10（顶部控制条与底部结果条压缩了可见高度）。
- 真机：iPhone 13 Pro（iOS 26.5，`00008110-000620DC0AA2801E`），Team `2PX9496FD6` 签名构建 → `devicectl install` → `devicectl process launch` 成功（进程 7619），`Assets.car` 含 `AppIcon`，`CFBundleIconName=AppIcon`。
- 说明：本机未配置图像生成模型（Settings → Models → Image generation model 为空），图标由 CoreGraphics 脚本绘制，不是生成模型产物。

## 遮罩可见性复核、抽屉组件与首页行为控制

- 复核「背景开启但看不到」：`PopoverHostView` 的遮罩层按 `showsBackdrop` 与 `appearance.backdropOpacity` 计算并渲染（`backdropOpacity` getter 会先看 `showsBackdrop`）。实际看不到是因为 `.bottomSheet` 预设设了 `showsBackdrop = false`（阅读器默认无遮罩），确认框等预设默认 0.32。新增回归测试 `testBackdropDimmingFollowsPresetAndShowsBackdrop`：确认框默认 0.32、`showsBackdrop = false` 后 0、重新开启回 0.32；操作列表预设 0、手动开启后 0.32。
- 新增 `BoneDrawerSheetView`：标题 + 抓手 + 分组行；`.single`（点击即选中并关闭）、`.multiple`（保留弹窗、勾选、完成按钮、`onConfirm` 回传）、`.none`（仅回调）；`setSelected(indices:)` 用跨分组连续的扁平索引，`dismissesOnSelect`、`showsCancel`、`cancelTitle`/`confirmTitle` 支持运行期修改；行支持 `detail`、`image` 与 `isDestructive`（仅红色语义）。表面复用 `.bottomSheet`，默认显示抓手、标题居中。
- 首页控制条由 2 行扩到 4 行：外观、动画、遮罩（预设/显示/隐藏）、交互（预设/允许穿透/拦截触摸）；展示前按选择写入 `configuration`，选「预设」时保持各预设默认。新增场景 18「抽屉式选择」，Demo 共 19 个场景。
- 测试：核心 **86/86 通过**（`core-drawer.log`，新增抽屉单选/多选与遮罩 3 项）；Demo UI `testDrawerSceneSelectsRowAndReportsResult` **1/1 通过**（`ui-drawer.log`）。
- 真机：iPhone 13 Pro（iOS 26.5），Team `2PX9496FD6` 构建成功 → `devicectl install` → `process launch` 成功。
- 追加修正：`BoneDrawerSheetView` 的用法改为与阅读器旧实现一致——`init(title:)` + `addButton(text:value:style:inSection:callback:)` + `selectAction { [(text, value)] }`，分区类型 `.normal/.singleSelect/.multipleSelect/.drag`，`sheetConfig`（`openSectionTitle`/`sectionHeight`/`fontSize`/`cellHeight`/`highlightColor`/`textAlignment`）与 `confirmTitle`/`cancelTitle` 保留。此前的 `init(sections:)` + `onSelect/onConfirm` 组合已移除。
- 过程中发现并修复：`addButton` 最初用整个 `SectionType` 比较分区，`singleSelect("翻页", true)` 与 `("翻页", false)` 会被当成两个分区；按旧实现改为**按标题匹配**，初值 Bool 只决定新行默认选中。修复前测试报 `["平移"] != ["平移", "深色"]`（`drawer-tests3.log`），修复后 4 项抽屉测试通过（`drawer-tests4.log`）。
- 重新验证：核心 **87/87 通过**（`core-drawer2.log`）；Demo UI `testDrawerSceneSelectsRowAndReportsResult`（先点“仿真”再点“确定”，结果条显示“抽屉提交：仿真”）**1/1 通过**（`ui-drawer2.log`）。真机：iPhone 13 Pro 构建 → 安装 → 启动成功。

## 抽屉行的背景色与分组圆角（对齐阅读器 SheetCell）

- `SheetConfig` 新增 `cellBackgroundColor`（默认 `.secondarySystemBackground`）、`cellCornerRadius`（默认 10）、`horizontalInset`（默认 16）、`cellSeparatorColor`（默认 `.separator`）；行背景改为独立背景层，按分区首/中/末决定 `maskedCorners`，最后一行不画分隔线，与阅读器 `BoneDrawerSheetCell.roundStyle` 一致。
- 面板底色仍由 `configuration.appearance.backgroundColor` 控制（`.bottomSheet` 为 `systemBackground`），与行背景相互独立。
- 真机/模拟器取色核对（深色模式，截图 `Screenshots/iPhoneDuo/drawer-cells-dark.png`）：面板 `#000000`（systemBackground）、行背景 `#1C1C1E`（secondarySystemBackground）、分隔线 `#383838`，行高 54.3 点、两侧 16 点内缩，圆角落在分区首尾行。
- 测试：`testRowBackgroundColorAndGroupedCorners` 断言默认行背景与首尾 `maskedCorners`，并验证改 `cellBackgroundColor`/`cellCornerRadius` 后立即生效；核心回归 **88/88 通过**（`core-drawer4.log`）。

## 抽屉头部对齐阅读器（关闭在右上、确定在左上）

- 布局改为：标题居中，右上角关闭按钮（×，40 × 40 命中区、辅助功能标识 `drawer-close`），有选择型分区时左上角显示“确定”（capsule，标识 `drawer-confirm`）；底部不再放取消行。
- `cancelTitle` 更名为 `closeAccessibilityLabel`，只作为关闭按钮的辅助功能标签（默认“关闭”），不再渲染为文字按钮；`confirmTitle` 仍控制“确定”文案。
- 过程中发现并修复真实缺陷：`rebuildRows()` 每次只移除行、没有移除分区标题，重复重建让面板不断长高（`contentStack` 从 11 → 14 → 17），最终铺满可用高度，右上角的按钮因此被挤到屏幕顶端且 `isHittable == false`。改为“保留首个标题行、其余全部重建”后行数稳定为 7、面板高度回落到内容高度，按钮可点。
- 测试：新增 `testHeaderPlacesCloseAtTopRightAndConfirmAtTopLeft`（关闭按钮位于右上、确定位于左上、确定可提交）与 `testDemoConfigurationKeepsRowCountStable`（7 行、面板高度 < 600）；抽屉用例 **7/7 通过**（`drawer-rows3.log`），Demo UI `testDrawerSceneSelectsRowAndReportsResult` **1/1 通过**（`ui-drawer8.log`），核心回归见 `core-drawer5.log`。

## 抽屉头部顺序修正（左关闭、右自定义按钮）

- 按用户要求改回阅读器的左右关系：左侧关闭按钮（×，40 × 40，标识 `drawer-close`），右侧为可自定义按钮（标识 `drawer-confirm`，默认“确定”，仅在有选择型分区时显示并提交选中项）；标题居中。
- 新增 `trailingButton` 供宿主改文案/图标，`onTrailingButtonTap` 接管点击：设置后按钮始终显示，点击只执行自定义回调、不再默认提交关闭。
- 测试：`testHeaderPlacesCloseAtTopLeftAndTrailingButtonAtTopRight`、`testCustomTrailingButtonReplacesDefaultConfirm` 等抽屉用例 **8/8 通过**（`drawer-header3.log`）；核心回归见 `core-drawer6.log`；Demo UI 抽屉用例保持通过。

## 抽屉右侧按钮默认隐藏（两种取结果方式）

- 右侧按钮不再随选择型分区自动出现：默认 `showsConfirmButton = false`（隐藏），需要统一提交时显式打开；`onTrailingButtonTap` 设置后同样会显示并接管点击。
- 两种取结果方式与阅读器一致：
  1. 多选/需要统一提交：`showsConfirmButton = true` → 点右侧按钮执行 `confirm()`，按分区顺序把选中项通过 `selectAction` 回传并关闭；
  2. 单选/立即执行：`.normal("")` 行 + 每行 `callback`，点行即回调并关闭，不显示右侧按钮（旧实现里的用法）。
- 测试：新增 `testTrailingButtonHiddenByDefault`，并把提交类用例改为显式打开按钮；抽屉用例 **9/9 通过**（`drawer-hidden.log`）；Demo 场景 18 打开 `showsConfirmButton` 演示“确定”提交，UI 用例 **1/1 通过**（`ui-drawer9.log`）。

## 抽屉关闭按钮改为向下箭头（与操作列表一致）

- 关闭按钮外观抽成共用实现 `applyPopoverCloseButtonStyle(_:style:)`：操作列表与抽屉同一套观感（12 点 `chevron.down`、iOS 26+ 液态玻璃圆圈、早期标题色 8% 圆圈），尺寸取 `contentStyle.resolvedCloseButtonSize`，图标可被 `contentStyle.closeButtonImage` 覆盖。
- 抽屉头部由 `xmark` 改为该向下箭头，位置仍在左侧；`applyContentStyle` 时同步刷新外观。
- 测试：抽屉用例（含新增“关闭按钮应有箭头图标”断言）与预设布局用例 **14/14 通过**（`drawer-closeicon2.log`），核心 **92/92**（`core-drawer8.log`），Demo UI 抽屉用例 **1/1**（`ui-drawer10.log`）。

## 抽屉“确定”按钮沿用左侧关闭按钮样式

- 外观抽成通用实现 `applyPopoverCircleButtonStyle(_:style:title:image:)`：传 `title` 显示文字（如“确定”），不传显示图标（关闭箭头）；关闭按钮的 `applyPopoverCloseButtonStyle` 只是它的图标分支。
- 两个按钮共用尺寸常量：高度都取 `contentStyle.resolvedCloseButtonSize`（默认 40），圆角取高度一半，`contentStyle.closeButtonSize` 变化时一起同步（新增 `updateHeaderButtonSizes`）。
- 玻璃样式会丢弃 `titleLabel.font`，文字字体改由 `configuration.titleTextAttributesTransformer` 固定为 13 点 semibold；文字态左右内边距收窄到 8 点，两字标题渲染宽度接近左侧圆圈直径。
- 标题排版不再把两个圆形按钮交给 `applyPopoverTypography`（它会重置按钮字体与内边距），只作用于标题与占位正文。
- 新增用例 `testConfirmButtonSharesCloseButtonStyle`：同一界面下实测关闭按钮 `40×40`、确定按钮 `42×40`，高度完全一致、`cornerStyle` 相同、确定按钮无图标且标题为“确定”。
- Demo 增加 `--demo-scene <n>` 启动参数（`DemoViewController.viewDidAppear` 中首次呈现），方便截图与排查时直接打开指定场景。
- 测试：核心 **93/93 通过**（`core-confirmcircle.log`），Demo UI 用例 **5/5 通过**（`ui-drawer14.log`）。

## 遮罩玻璃（透明度可调 + 可选虚化）

- 遮罩拆成两个互不影响的旋钮：`appearance.backdropOpacity`（已有，默认 0.32）管压暗浓度，新增 `appearance.backdropGlass`（默认 `false`）选择是否叠加玻璃模糊，`appearance.backdropGlassStyle`（默认 `.systemUltraThinMaterial`）指定模糊材质。
- 实现：`PopoverHostView` 新增 `backdropGlassView`（`UIVisualEffectView`），垫在压暗层下面；玻璃只跟「开关 + 是否可见」走，透明度变化不影响虚化强度，因此 `backdropOpacity = 0` + `backdropGlass = true` 就是纯模糊遮罩。
- 与既有开关的关系：`showsBackdrop = false` 一并关掉虚化；`respectsReduceTransparency`（默认 `true`）且系统开启「减弱透明度」时玻璃不生效，只剩压暗，和表面材质的降级规则一致。
- 动画：进出场、拖动关闭时玻璃层与压暗层同步淡入淡出（拖动按位移比例衰减），打断动画会冻结当前实际透明度，不出现玻璃瞬间跳满。
- 新增 `PopoverBackdropGlassTests`（4 项）：默认不画玻璃层、开启后挂上模糊且不改变 0.32 压暗、`backdropOpacity = 0` 仍是纯模糊、`showsBackdrop = false` 连玻璃一起关、材质与颜色可配置并可关闭。
- Demo：首页「遮罩」控制新增第 4 项「玻璃遮罩」；新增场景 20「玻璃遮罩」，可在弹窗内切换玻璃开关与 0 / 0.12 / 0.32 三档不透明度。
- 测试：核心 **97/97 通过**（`popover-glass1.log`，含 4 项新用例）。

## 抽屉配色改为「灰底白行」（系统分组列表观感）

- 面板底色：`BoneDrawerSheetView.init` 在 `.bottomSheet` 预设之后覆盖 `configuration.appearance.backgroundColor = .systemGroupedBackground`（浅色浅灰 / 深色纯黑）。
- 行（cell）底色：`SheetConfig.cellBackgroundColor` 默认值由 `.secondarySystemBackground` 改为 `.secondarySystemGroupedBackground`（浅色纯白 / 深色 #1C1C1E），与灰底形成分组列表的层次，深色下也不会出现「黑字块糊在一起」。
- 两者仍各自独立：`configuration.appearance.backgroundColor` 改面板，`sheetConfig.cellBackgroundColor` 改行，任一改动即时重排。
- 用例 `testRowBackgroundColorAndGroupedCorners` 更新为断言面板 `.systemGroupedBackground`、行 `.secondarySystemGroupedBackground`，并断言两者默认不同色，避免将来又被改成同一层。
- 测试：核心 **97/97 通过**（`popover-drawerpalette.log`）。

## 抽屉行图标与表头留白

- `addButton` 新增可选 `icon:`（`UIImage?`，默认 `nil`）；不传时行结构与旧版本完全一致，只有传了才在行首插入「底板 + 图标」。
- 新配置项（默认值即旧观感）：`cellIconSize` 32、`cellIconCornerRadius` 9、`cellIconBackgroundColor` `nil`（不画底板）、`cellIconTint` `nil`（跟随 `highlightColor`）、`cellIconSpacing` 12、`headerInset` 16。
- 带图标的行，分隔线从文字起始处缩进（与系统分组列表一致）；无图标行仍是原来的 15 点内缩。
- 表头跟随 `headerInset`：关闭按钮与右侧按钮贴边留白，标题左右为「留白 + 按钮宽度 + 8」，标题字号默认改为 17 点 semibold。
- 新增用例 `testRowIconIsOptionalAndConfigurable`：有图标行出现 `drawer-row-icon`（32×32、圆角与底板色取自 `sheetConfig`、图标约底板 58%），无图标行没有该视图，`headerInset` 默认 16。
- Demo 场景「抽屉式选择」的 6 行都加了 SF 图标（靛蓝底板 + 靛蓝图标），恢复默认一行保持纯文字，用于对比两种布局。
- 测试：核心 **98/98 通过**（`drawer-icons3.log`）；Demo UI 抽屉用例 **1/1 通过**（`drawer-ui1.log`），带图标后行仍可点、仍能提交并关闭。

## 抽屉改用 UITableView（对齐阅读器实现）

- 结构从「UIStackView 手工堆行」换成 `UITableView(style: .grouped)`：`BoneDrawerSheetView` 持有 `tableView`，实现 `UITableViewDataSource / Delegate`；新增 `BoneDrawerSheetCell`（cell 透明、`baseView` 承担底色与分组圆角、`lineView` 自绘分隔线、`iconBox` 行首图标、`accessoryImageView` 勾选/拖动图标，`isSelected` 直接控制勾选显隐）。
- 表头仍是 `UIStackView` 的第一行（抓手由面板负责、标题居中、左侧关闭、右侧可选“确定”），列表紧跟其后。
- 列表高度按分区自算（`行数 × cellHeight + 分区间距`），超过 `sheetConfig.maximumListHeight`（默认 500）时 `isScrollEnabled = true`，并把 `configuration.scrollsOverflow` 关掉，避免外层与列表抢手势。
- `.drag` 分区恢复拖动排序：`UITableViewDragDelegate / DropDelegate` 只允许同一 `.drag` 分区内移动，落点即插入位置，提交时仍按当前顺序回传。
- 分隔线：有图标的行从文字起始处缩进，无图标行 15 点；末行不画。颜色、圆角、行高、图标参数继续走 `sheetConfig`。
- 测试改为通过 table view 驱动：`tapRow` 调用 `didSelectRowAt`，行背景/图标断言改成拿 `BoneDrawerSheetCell` 的视图；新增 `tableView.style == .grouped` 断言。核心 **98/98 通过**（`td-all.log`），Demo UI 抽屉用例 **1/1 通过**（`td-ui2.log`）。

## 抽屉 cell 文字错位修复（Auto Layout 与手写 frame 冲突）

- 现象：换成 `UITableView` 后行文字停在左上角、不在白色行背景里，行首图标与分隔线也塌成 0 尺寸。
- 原因：cell 的子视图既被设为 `translatesAutoresizingMaskIntoConstraints = false`，又只在 `layoutSubviews` 里手写 `frame`；`contentView` 的 Auto Layout 通道随后把这些没有约束的视图重置成零/固有尺寸。实测 `UILabel` 变成 `(0, 0, 32, 19.3)`、`iconBox` 变成 `(0, 0, 0, 0)`。
- 修复：cell 内部完全改为 frame 排版（与阅读器 `pin` 一节一致），不再让子视图参与 Auto Layout；分隔线高度也改成 frame 计算。修复后实测：行背景 `(16, 0, 358, 55)`、行首图标 `(32, 11.5, 32, 32)`、文字 `(76, 17.5, 250, 20)`、勾选 `(338, 17.5, 20, 20)`、分隔线 `(31, 54.5, 328, 0.5)`，全部落在行内。
- 有图标的行分隔线从文字起始处（`textLeft`）开始，无图标行仍为 15 点内缩。
- 验证：核心 **98/98 通过**（`td-all2.log`）；真机包已重装并启动 `dev.bone.BonePopoverDemo`。

## 抽屉标题上移、标题与列表间距加大

- 新增 `sheetConfig.headerTopSpacing`（标题上下留白，默认 10 点）与 `sheetConfig.listTopSpacing`（标题到列表间距，默认 10 点）；`rebuildRows()` 会同步这两条（表头约束改常量、`contentStack` 的 `setCustomSpacing`）。
- 面板内容顶部内边距由 4 点收到 0，标题整体上移约 4 点；配合标题留白 14→10，标题比之前更贴近抓手。
- 标题与列表之间不再紧贴，默认留 10 点。
- 验证：核心 **98/98 通过**（`spacing-tests.log`）。

## 抽屉空标题分区自动收缩

- `headerHeight(forSection:)` 统一计算标题行高度：第一区 0.01；未开 `openSectionTitle` 用 `sectionHeight`；开了标题但该分区标题为空时**退回 `sectionHeight`**（10 点），不再固定占 35 点。`viewForHeaderInSection` 对空标题分区返回 `nil`。
- 列表总高度改成按分区求和（不再用「分区数 × 统一高度」），空标题分区不会多留白。
- 新增用例 `testEmptySectionTitleShrinksHeaderHeight`：第一区 0.01、有标题 35、无标题 10，且无标题分区没有标题视图。
- 验证：核心 **99/99 通过**（`shrink-tests.log`）。
