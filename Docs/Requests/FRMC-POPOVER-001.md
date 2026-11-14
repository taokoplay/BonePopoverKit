# BonePopoverKit 扩展需求评估稿：确认框按钮标题可配置

状态：**历史需求与实现记录**。正文基于下述精确版本起草，保留当时的调研、提案与验收口径；当前接入以[使用说明](../UsageGuide.md)和[迁移说明](../Migration.md#action-sheet-migration)为准。

- 缺口分类（按 bone-project-bootstrap 第 5 步）：**3. 可复用 SDK 缺口**
- 证据强度：代码级不对称（内置组件之间）+ 单语言 Demo 实际渲染；**暂无多语言消费方实测数据**，请按此强度评估。
- 起草方式：仅做源码/文档核对与缺口整理，未修改 SDK 仓库、未 fork、未开 Issue、未发消息。

当前 API 补注：Alert 已公开 `confirmTitle` / `cancelTitle`。底部操作列表统一使用 `BoneDrawerSheetView`，旧 `BoneActionSheetView`、`PopoverAction` 已删除，不保留兼容 alias。下文出现的旧操作列表初始化器、cancelTitle、源码行号及测试数量均为历史证据，不代表当前可用 API 或本次验证结果。

## 请求与版本

- 需求编号/日期：`FRMC-POPOVER-001` / 2026-11-12
- SDK：BonePopoverKit（自研，UIKit 弹层）。仓库 `https://github.com/taokoplay/BonePopoverKit`。
  - 所用精确版本：本地仓库 `6ba9ecc4b217172107e03880015dc2c3d34da604`（main，无 Tag）。
  - 远端核对：2026-11-12 执行 `git ls-remote --symref https://github.com/taokoplay/BonePopoverKit.git HEAD` → `cfcad013a73744b19aeea3e3475b88ba3920d46f`（refs/heads/main）；`git ls-remote --tags --refs` 返回 0 行，确认**无 Tag**。本地比该远端 main 多 3 个提交（`0b486df`、`40e5160`、`6ba9ecc`），即本稿核对的是**尚未推送的本地版本**，转交时请一并同步或指定基线。
  - 平台：`swift-tools-version: 5.9`，`platforms: [.iOS(.v15)]`，无外部 Swift Package 依赖、无 bundle 资源。
- 消费项目：`Examples/BonePopoverDemo`（`dev.bone.BonePopoverDemo`，iOS 15+，UIKit；已安装并在 iPhone 13 Pro / iOS 26.5 真机启动）。项目本身当前只有中文 UI，未使用该能力。
- 请求者/优先级：本仓库维护者（用户）提出；优先级**待评估**。
- 调研证据（均为上述精确版本）：
  - `Sources/BonePopoverKit/PopoverPresets.swift`
    - `BoneAlertView.init(title:message:callback:)`（:81）、`init(title:placeholder:callback:)`（:91）：**没有按钮标题参数**。
    - `viewDidLoad` 内 `configurePopoverButton(confirmButton, title: "确认", prominent: true)`（:116）、`configurePopoverButton(cancelButton, title: "取消", prominent: false)`（:117）：标题是字面量。
    - **历史 API，现已删除**：`BoneActionSheetView.init(title:message:actions:cancelTitle:)`（当时 :254）的 `cancelTitle: String = "取消"` 已参数化；动作标题来自旧 `PopoverAction(_ title:)`。当前操作列表改用 BoneDrawerSheetView + addButton(text:...)，默认没有取消行。
  - `configurePopoverButton`（:409-416）只在创建时写入 `configuration.title`；`applyPopoverTypography`（:420+）注释明确“保留按钮已有标题”，样式刷新不回写标题。
  - 检索结论：`Sources/` 下无 `*.strings` / `*.lproj`；`Package.swift` 无 `resources:`。因此 SDK 没有可覆盖的内置文案资源。相关但独立的中文文案还有：关闭按钮 `closeButton.accessibilityLabel = "关闭"`（:301）、`BoneToastView` 用中文作 key 的 `NSLocalizedString("成功"/"失败"/"提示"/"加载中")`（:211-214）、背景遮罩用英文 key `NSLocalizedString("Dismiss")`（`PopoverHostView.swift:59`）。

## 业务问题与复现

- 用户在什么场景做什么操作：英文（或任意非中文）App 使用内置确认框 `BoneAlertView(title:message:)` 或输入框 `BoneAlertView(title:placeholder:)` 做删除确认、重命名、保存提醒等普通操作。
- 当前行为：弹窗标题/正文由宿主提供，但两个按钮固定显示中文 **“确认” / “取消”**，与 App 其余 UI 语言不一致；宿主 API 上没有任何入口在展示前指定这两个标题。
- 期望行为：宿主可以在创建确认框/输入框时（或在 `configuration` 中）指定按钮标题，未指定时保持现有中文默认值；同一份能力也应适用于自定义内容面板的宿主自建按钮场景的一致体验。
- 用户影响与频率：影响所有非中文界面消费方，属于**每条确认流程都会出现**的可见缺陷；当前仓库内没有这样的消费方，故没有线上影响数据（未知）。
- 最小脱敏复现（Demo 中即可复现，不需要真实数据）：
  - 步骤：在 `Examples/BonePopoverDemo` 中打开任意确认框场景（场景 0「保留熟悉的使用方式」）。
  - 实际结果：按钮文字为“确认”“取消”，无法通过公开 API 在首次布局前改成其他语言。
  - 期望结果：能由宿主传入 “OK / Cancel” 等文案，且不改变现有默认。
- 与既有配置/宿主 bug/版本不匹配的区别：不是样式配置漏项，也不是宿主用法错误——`PopoverContentStyle` 只管字体/颜色/对齐/间距，`applyContentStyle()` 明确不回写标题；两个 alert init 的参数表里确实没有标题位。

## 为什么考虑进入 SDK

- 起草时 API 已覆盖什么、差什么：内容、样式、布局、关闭语义、无障碍标识都已覆盖；**只差按钮文案的注入点**。当时的 `BoneActionSheetView.cancelTitle`（现已删除）用于说明“按钮标题参数化”的可行性，不是当前推荐用法；当前 Alert 使用自身 confirmTitle / cancelTitle，操作列表使用 BoneDrawerSheetView。
- 已尝试或查过的公开能力：`BoneAlertView.confirmButton` / `cancelButton` 是 `public let`，`BoneAlertView` 是 `open class` 且 `viewDidLoad` 为 `open override`；`PopoverConfiguration.contentStyle` 不含标题字段。没有其它公开入口。
- 可在宿主实现的替代及实际代价：
  1. **加载后覆盖**：`alert.loadViewIfNeeded()` 之后改 `alert.confirmButton.configuration?.title`。可行且样式刷新不会回写，但属于隐式约定：每个实例都要手动写、`UIButton.Configuration` 状态需自行重建、无处发现、SDK 若将来调整按钮配置方式即失效；首次 `viewDidLoad` 到宿主覆盖之间还可能有一帧中文。
  2. **子类化**：重写 `viewDidLoad()` 后重新配置两个按钮。代价是宿主复制 SDK 内部按钮配置（`filled`/`tinted`、`cornerStyle`、最小高度 44 点），SDK 改样式即静默偏离，且仍要处理横排/竖排重排。
  3. **改用自定义内容**：`BonePopoverView(contentView:)` 全自绘。可行但放弃内置的排布、无障碍、键盘与尺寸测量，属于重造成本。
  结论：三种替代都成立但都是“绕过”，对一个 5 行就能补齐的参数化能力来说代价过高，且是 **SDK 通用能力**（每个非中文 App 都要付一次）。
- 可复用于哪些项目/能力：所有使用 BonePopoverKit 内置确认框/输入框的 App（含读取器、工具类 App 的删除/重命名/导入确认）。这是**推断**的复用面，本仓库内暂无第二个消费方证据。
- 判断：**SDK 通用能力**（按钮文案注入），不是宿主业务。若 SDK 开发 AI 判定应保持“内置文案由宿主覆盖”，请说明期望的官方覆盖方式并写入文档，以便宿主停止使用隐式覆盖。

## 责任边界与建议

- SDK 负责：为内置确认/输入框提供按钮标题的公开入口；保持默认值、布局测量、无障碍标签与横竖排行为不变；文档写清标题变更后的重新测量方式。
- 宿主负责：提供已本地化的字符串（`NSLocalizedString` 等），决定业务语义文案（“删除”“放弃”“保存”），不要求 SDK 内置多语言 bundle。
- 后端/模型服务/平台配置负责：无。
- 最小功能范围：`BoneAlertView` 两种 init 的可选按钮标题 + 运行期可改；不改按钮数量、层级、关闭语义。
- 非本次目标：Toast 类型文案、背景遮罩 “Dismiss”、关闭按钮 “关闭” 等其它硬编码/中文 key 文案的本地化策略（相关，但应另行决定）；SDK 内置语言包；RTL、复数、动态字符串模板。
- 可选 API 草案（**建议，尚不存在**，请自行取舍）：
  ```swift
  // 建议 1：init 参数，nil 表示沿用内置默认文案
  public init(title: String, message: String,
              confirmTitle: String? = nil, cancelTitle: String? = nil,
              callback: @escaping () -> Void)
  public init(title: String, placeholder: String,
              confirmTitle: String? = nil, cancelTitle: String? = nil,
              callback: @escaping (String) -> Void)

  // 建议 2：值类型配置，便于显示期间修改，与 contentStyle 的用法一致
  public struct PopoverButtonTitles {
      public var confirm: String?   // nil = SDK 内置默认
      public var cancel: String?
      public init(confirm: String? = nil, cancel: String? = nil)
  }
  // configuration.buttonTitles = PopoverButtonTitles(confirm: "OK", cancel: "Cancel")
  // 变更后需要重新测量面板尺寸（可复用现有 invalidatePopoverLayout()）。
  ```
  错误与取消语义不变：按钮点击仍先关闭再回调，`shouldDismiss` 仍不拦截内置按钮；空字符串与 `nil` 的区别需明确（建议 `nil` = 默认，空字符串按无效处理并回退默认）。

## 兼容性与资源

- 旧调用/存储格式/协议迁移：纯新增可选参数与配置字段，现有 `BoneAlertView(title:message:callback:)` 调用与 `.bottomSheet` 等预设不变；不涉及存储、协议或窗口会话。
- 默认行为：默认值仍为 “确认 / 取消”，旧二进制行为完全一致；无需迁移开关。
- 线程与生命周期：新增入口与现有 UIKit API 一致，`@MainActor`；不引入后台任务、通知或跨窗口状态。标题在显示期间变更需要重新测量宽度（与现有 `contentStyle` 变更路径相同）。
- 包体/内存/网络/启动成本：无新增资源、无网络；仅在宿主传入标题时改变文本，测量成本与现有样式变更同级，无预算需要新增测量口径。
- 凭据/隐私/数据边界：无凭据、无用户数据；仅界面字符串。若选择内置语言包，会引入 bundle 资源与维护成本，本稿不建议。

## 可验证验收

1. 当宿主用 `BoneAlertView(title:message:confirmTitle:cancelTitle:)` 传入 “OK / Cancel”，展示确认框时可观察到两个按钮分别显示 “OK”“Cancel”，标题/正文与原有样式一致。
2. 当宿主不传标题（或传 `nil`），展示确认框时可观察到按钮仍为 “确认 / 取消”，与当前版本截图一致，面板尺寸不变。
3. 当宿主用输入框形态传入自定义标题并提交，键盘避让、横排/竖排切换（辅助功能字号）、先关闭再回调的顺序均与当前版本一致；连续打开三个不同语言的确认框，前一个实例的文案不影响后一个。
4. 显示期间把这些标题改成长文案，可观察到面板重新测量、按钮文字不截断或按既有规则换行，且 `confirmButton` / `cancelButton` 的辅助功能标签与新标题一致。
5. 旧消费者：`Examples/BonePopoverDemo` 现有场景（未传标题）在 Duo 模拟器与 iPhone 13 Pro 真机上渲染结果与改动前一致，核心 74 项测试仍通过。

## 当前项目进度与请 SDK 开发 AI 回答的结论

- 当前采用的临时方案：**未采用**。本项目 Demo 只有中文，未做加载后覆盖；如需立刻支持英文，宿主可先按上文“加载后覆盖”实现并明确回退方式（SDK 补齐后删除该适配）。
- 哪些工作可继续、哪些核心能力阻塞：Demo 与现有场景、当前 74 项核心回归、真机安装均不受影响；**任何非中文 UI 消费方会被这个硬编码阻断**（每条确认流程都可见），但本仓库当前没有这类消费方，故不构成当下阻塞。
- 请判断：
  - 是“已有能力可覆盖”（若是，请给出官方覆盖方式并写入文档）／“应放宿主”（若是，请给出稳定契约，避免宿主依赖 `UIButton.Configuration` 细节）／“建议 SDK 接受”／“暂缓或拒绝”。
  - 若建议接受：请给出参数或配置的最终形态、`nil`/空字符串语义、运行时变更的重新测量要求、需要补的测试范围、兼容风险与建议版本号；本稿不视为实现授权。

本稿不自动创建 Issue、发送消息、修改 SDK、发布版本或承诺完成时间。

## 追加：本仓库已先行实现（2026-11-12）

本稿核对后，本仓库（SDK 侧）已直接落地其中最小方案，转交时可作为“已有实现参考”而非待评估提案：

- 当时实现使用 `configuration.buttonTitles`（`PopoverButtonTitles`，字段默认 nil）+ `BoneAlertView.confirmTitle` / `cancelTitle`；空串视为未配置，显示期间修改立即生效并重新测量。此处保留早期方案记录，当前文案配置请使用各组件公开属性，见[阅读器对照](../ReaderParity.md)。
- 默认值仍为“确认”“取消”，旧调用与渲染不变；宿主直接改写 `button.configuration?.title` 的旧路径继续被保留（仅在配置项变化时回写）。
- 验证：`Tests/BonePopoverKitTests/PopoverReaderParityTests.swift`（5 项）、核心回归 79/79；记录见 `Docs/Validation.md`。
- 仍未做：`nil`/空串之外的语义（如 `String` 模板、内置多语言包）与其它硬编码文案（关闭按钮 a11y 标签、Toast 类型文案）未一并处理。

## 当前操作列表迁移补注

普通动作、单选、多选、同分区拖动及固定高度滚动均使用 `BoneDrawerSheetView(title:message:)`。逐行调用 `addButton(text:value:icon:style:inSection:dismissesPopover:accessibilityIdentifier:callback:)`（除 text 外均有默认值），返回 Void；普通行默认先关闭再回调，dismissesPopover: false 即时回调且保持面板。选择型分区显式设置 showsConfirmButton = true 并通过 selectAction 提交，右按钮默认隐藏。

旧操作列表的 actions / addAction、actionButtons、cancelButton / cancelTitle 以及返回 UIButton 的 addButton 均已删除；默认通过左侧向下箭头关闭，相关入口是 closeButton、showsCloseButton 和 closeAccessibilityLabel。操作列表右侧 confirmTitle、trailingButton、onTrailingButtonTap 保留；Alert 自身的 confirmTitle / cancelTitle 不受这次列表迁移影响。
