# 原组件项目清点

本次先扫描用户指定的 `/Users/xutaoyu/CodeSource/PI-Plugins-worktrees`：该目录仅有两个 JS 插件 worktree，33 个文本文件中没有 BonePopoverView 或 iOS 源码。经用户明确选择后，扫描范围扩大到整个 `/Users/xutaoyu/CodeSource`。

## 含真实实现的全部项目目录

以下路径相对于 `/Users/xutaoyu/CodeSource`。Swift 命中数排除测试和 Package.swift，包含类型定义、注释及字符串，**不是运行时调用次数**。

| 仓库目录 | 主 checkout Swift 命中文件 / 字面引用 | 核心实现份数（含 worktree） | 状态 |
| --- | ---: | ---: | --- |
| `BoneProject/ParsingBook` | 89 / 94 | 46 | 主项目 + 45 个 worktree；业务扩展最多 |
| `BoneProject/PillLog-iOS` | 6 / 9 | 2 | 主项目 + 1 个 worktree；位于 LegacyUI |
| `BoneProject/StudyPlan/StudyPlan-iOS` | 8 / 11 | 1 | 含旧组件及业务子类 |
| `BoneProject/TaokoManage-iOS` | 10 / 13 | 1 | 含旧组件及业务子类 |
| `BoneProject/Wecat` | 14 / 17 | 1 | 含旧组件及业务子类 |
| `BoneProject/Tulai/ValuablePicture-iOS` | 13 / 16 | 1 | 图来项目目录 |
| `ValuablePicture-iOS` | 12 / 15 | 1 | 另一份仓库；核心与图来相同，业务调用不同 |
| `BonePackage/BonePopoverView` | 3 / 6 | 1 | 已存在的早期独立 Swift Package |
| **合计** | **155 / 181** | **54** | **8 个真实实现目录** |

另有 `BoneProject/NiceBook/NiceBook-iOS`：只在 HTML 原型/文档中出现，没有原生实现，不能列为正在使用原生 SDK 的项目。

“含有源码”不等于“当前 target 编译并运行该组件”。本次未构建原 App；PillLog 的抽屉已被简化为 stub，是否仍有运行时调用需在迁移时确认。

## 核心文件入口

- ParsingBook：`BoneProject/ParsingBook/ParsingBook/Custom/BonePopoverView/Basics/BonePopoverView.swift`
- PillLog：`BoneProject/PillLog-iOS/PillLog-iOS/LegacyUI/BonePopoverView/Basics/BonePopoverView.swift`
- StudyPlan：`BoneProject/StudyPlan/StudyPlan-iOS/StudyPlan-iOS/Custom/BonePopoverView/Basics/BonePopoverView.swift`
- TaokoManage：`BoneProject/TaokoManage-iOS/TaokoManage-iOS/Custom/BonePopoverView/Basics/BonePopoverView.swift`
- Wecat：`BoneProject/Wecat/Wecat/Custom/BonePopoverView/Basics/BonePopoverView.swift`
- 图来：`BoneProject/Tulai/ValuablePicture-iOS/ValuablePicture-iOS/Custom/BonePopoverView/Basics/BonePopoverView.swift`
- ValuablePicture：`ValuablePicture-iOS/ValuablePicture-iOS/Custom/BonePopoverView/Basics/BonePopoverView.swift`
- 旧独立包：`BonePackage/BonePopoverView/Sources/BonePopoverView/Basics/BonePopoverView.swift`

## 去重结果与迁移影响

54 份核心文件按 SHA-256 去重得到 5 个版本：

| SHA-256 前 12 位 | 份数 | 分组 | 关键差异 |
| --- | ---: | --- | --- |
| `5a7e3b532fa9` | 46 | ParsingBook | 圆角 16、BoneThemeManager、sheet 顶部圆角、show(isNav:)、fade 操作 baseView、动画结束后回调 |
| `5c809c42c9ff` | 2 | PillLog | 圆角 10、LegacyUI、hidden 主动结束编辑、主题 unspecified 固定 light |
| `1c2d8d0b6fe4` | 4 | StudyPlan / TaokoManage / 两个 ValuablePicture | AppColor 依赖、show()、fade 操作整个 view、旧坐标布局 |
| `425ea58adac2` | 1 | Wecat | dismiss completion 在动画调度后立即执行 |
| `9c657deda043` | 1 | 旧 Package | 系统颜色替换；基类仅 public 而非 open；仍有提前 completion；window 未绑定 scene |

核心类相同不代表整套组件相同：配套管理器有 7 个版本，父控制器有 6 个版本，配置有 4 个版本。ParsingBook 主 checkout 的管理器已有绑定宿主 window/scene、关闭回调合并等改进，不能退回最早版本的全局窗口逻辑。

共追踪到 112 个不同子类名。代表性业务扩展包括：`RuleWebSheetView` 的 WebKit 滚动手势协调、`CacheSpaceActionSheet` 的缓存操作、AI 章节选择器的移除通知、阅读设置和多字段输入。它们保留在各 App，逐个接入新 SDK 的内容、尺寸与生命周期扩展点。

同名冲突尤其需要注意：旧项目/旧包的 `BoneAlertView` 是确认/单输入框；ParsingBook 的同名类却是多按钮/loading 弹窗，其确认/输入框叫 `BoneEasyAlertView`。新包当前采用前者的构造方法；迁移不能全局替换类名。

## 搜索口径与限制

- 使用文件名发现 + 全目录源码/工程元数据内容扫描，不依赖 `.gitignore`。
- 排除新建 BonePopoverKit、`.git`、`node_modules`、DerivedData、`.build`、常见构建缓存和二进制。
- 包含 Pods；实际两个 Starscream 示例 Pods 中命中为 0，没有直接类名命中归属于 Pods/checkouts/Vendor/3rdParty。
- 全 checkout 命中源码 4,803 文件 / 5,963 次；SHA-256 去重后 311 种源码内容。元数据命中 986 文件 / 2,484 次。
- 去掉测试及 Package.swift 后，Swift 命中 3,825 文件 / 4,017 次；主 checkout 为上表的 155 / 181。
- 8 个同名测试 stub 已剔除真实实现。360 个符号链接目标在授权根内按真实路径统计，不重复遍历别名。
- 4 个读取失败是 dev-main 示例中损坏的 mocha.css/mocha.js 链接，与组件源码无关。
- 原组件内嵌 CLPopover* 和 KeyboardObserver 有独立作者署名。新 SDK 重写承载、材质、动画及键盘处理，没有复制这些第三方实现，也未引入 PinLayout。

所有原 App 和早期独立包保持原状，本次修改仅位于新 BonePopoverKit 工作区。迁移步骤见 [Migration.md](Migration.md)。
