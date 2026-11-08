# 独立 Window 弹窗

本模式参考旧版“一弹窗一 Window”的能力，使用 `@MainActor`、值类型配置及按 Scene 隔离的窗口会话实现。内容继续由 BonePopoverKit 的样式、布局和动画系统管理。最低 iOS 15，无第三方运行依赖。

## 展示入口

| API | 覆盖范围与选择方式 |
| --- | --- |
| `show(from: presenter, animated:)` | 页面模式，添加到 presenter.view，不创建 Window |
| `show(over: sourceWindow, animated:)` | 独立窗口，绑定源 Window 所属 Scene，推荐多 Window 业务使用 |
| `show(in: scene, animated:)` | 独立窗口，明确指定 Scene，从该 Scene 找业务宿主 |
| `show()` | 独立窗口，仅有一个前台活动 Scene 时自动选择上下文 |
| `show(isNav: true)` | 兼容旧导航入口，自动选择唯一前台 Scene，为本次展示创建导航容器 |

所有方法返回 `Bool`。实例已展示、已经附着其他控制器、源 Window 不可见/无 Scene/无根控制器、层级非法或上下文不明确时返回 false。自动入口不使用 AppDelegate.window，也不跨 Scene 猜测窗口；Scene 的 key Window 若是 SDK 弹窗，会沿会话记录找到业务宿主。没有 key 时仅接受唯一可识别的可见普通业务窗口。

**行为迁移：** 本包早期版本的 `show()` / `show(in:)` 在页面中展示，现在改为独立窗口。需要原页面范围时用 `show(from:)`。旧子类重写 `show()` / `show(isNav:)` 时返回类型需为 `Bool`。

```swift
@MainActor
func showWindowAlert(from presenter: UIViewController) {
    guard let sourceWindow = presenter.viewIfLoaded?.window else { return }
    let alert = BoneAlertView(title: "保存配置", message: "窗口内的修改已经准备好。") {}
    alert.configuration.window.level = .alert - 1
    alert.configuration.window.stacking = .aboveManagedPopovers
    alert.configuration.window.keyPolicy = .takeAndRestore
    alert.show(over: sourceWindow)
}
```

## 窗口配置

所有配置位于 `configuration.window: PopoverWindowConfiguration`。

| 属性 | 默认值 | 说明 |
| --- | --- | --- |
| `level` | `.alert - 1` | 固定策略下为实际层级；自动策略下为最低层级 |
| `stacking` | `.aboveManagedPopovers` | 取最低层级、源 Window 与同 Scene 已有弹窗上方层级的最大值 |
| `keyPolicy` | `.takeAndRestore` | 接管 key，关闭后恢复有效的前驱 Window |
| `container` | `.plain` | 普通透明宿主；`.navigation` 提供 UIKit 导航栈 |

`.fixed` 严格采用配置的 level，可配合通知、护眼遮罩等业务约定。自动策略保证高于指定源 Window 及同 Scene 已管理的弹窗，不改变其他业务窗口，不承诺高于系统窗口或未来出现的任意更高窗口。无穷、NaN 或层级递增溢出会拒绝展示。

`.preserveCurrent` 让浮层保持非 key，不抢业务键盘；仅用于无需输入的提示。需要 UITextField/UITextView 输入时使用默认 `.takeAndRestore`。

**创建快照：** 一次展示使用当时的 window 配置。显示期间更改 level、stacking、keyPolicy 或 container，在下次展示生效。材质、字体、尺寸、背景及穿透等原有配置仍实时刷新。

## 自定义内容与导航

自定义控件放在 `baseView` 或通过 `setContentView` 设置；尺寸测量与页面模式一致，继续使用当前 bounds、安全区、键盘和保留区域。无需给业务控件写一份窗口专用布局。

```swift
@MainActor
func showNavigationPopover(over sourceWindow: UIWindow) {
    let sheet = BoneActionSheetView(title: "项目设置", actions: [PopoverAction("关闭")])
    sheet.configuration.window.container = .navigation
    sheet.show(over: sourceWindow)
    // 在业务按钮事件中可调用：
    // sheet.navigationController?.pushViewController(detailController, animated: true)
}
```

导航容器根页面默认隐藏导航栏。详情页可按业务需要显示导航栏、push/pop；弹窗作为透明宿主的子控制器，其 navigationController 是窗口导航容器。push 后宿主暂时离屏不会触发 hostRemoved；在详情页调用原弹窗的 `hidden()` 会关闭整个窗口会话。根宿主手动管理弹窗出现/消失回调，避免导航容器重复转发。

状态栏和支持方向在展示前从源业务控制器捕获，避免读取浮层自身造成递归。沿用源 Window 的显式浅色/深色覆盖，未指定时跟随 Scene 系统环境。SDK 不复制 MainTabNavController、全局导航栏 appearance 或 App 阅读转场。

## 触摸与输入

- 拦截外部点击：默认模式；dismissOnBackdropTap 决定是否关闭。
- 隐藏背景：`showsBackdrop = false` 仅控制视觉，不影响命中与关闭开关。
- 允许穿透：`allowsEventPenetration = true`，外部命中返回 nil，事件进入下层窗口。
- 穿透并关闭：同时启用 `autoHideWhenPenetrated`；观察实际接收触摸的下层窗口，在点击结束后请求关闭，底层控件动作继续执行。
- `shouldDismiss` 可拦截外部/穿透/滑动关闭请求，程序关闭及内置按钮仍直接关闭。

跨窗口观察器在同 Scene 的下层可见窗口上按需注册，窗口或配置改变时更新，导航根页面离屏时暂停。它不取消触摸、不延迟控件事件，也不把点击伪造或转发给其他窗口；`hitTest`、布局查询和鼠标移动不会关闭弹窗。

独立窗口的键盘避让使用键盘 frame 通知，转换到当前宿主坐标后参与布局；页面模式继续使用原有 `UIKeyboardLayoutGuide`。验证中发现独立 Window 创建键盘指南后，UIKit 的键盘跟踪器会继续持有已关闭窗口，因此窗口模式不创建该指南。回归测试会检查弱引用 Window 真正释放，而不只检查隐藏状态或会话数量。

## 所有权与关闭顺序

Scene 协调器 → 会话 → Window → 根宿主/导航容器 → 弹窗。弹窗、Window 和根宿主对会话使用弱引用；观察器对下层 Window 也使用弱引用。每次展示有单独 UUID，会话检查可避免晚到的动画、手势和通知误关重显后的弹窗。

关闭时：

1. 进入关闭状态、结束输入、完成退出动画。
2. 移除内容和父子关系，注销会话，隐藏 Window 并清空 rootViewController，移除观察器。
3. 若关闭前仍是 key，优先恢复同 Scene 有效的 SDK 输入窗口，否则恢复有效的原 key Window，最后回到源业务窗口。
4. 仅在合适的窗口恢复输入/辅助功能焦点；用户已切换 key 时不抢回。
5. 清理完成后发出通知和 completion。多次关闭的 completion 各执行一次，关闭通知一次；回调可立即重显同一实例。

下层弹窗先关闭会重接上层的恢复链，避免恢复到已销毁 Window。源 Window 隐藏或 Scene 断开会按 hostRemoved 清理对应会话；其他 Scene 保持独立。Scene 断开不尝试恢复该 Scene 的输入。

## Demo 与验证

Demo 提供“多窗口展示”入口及独立测试入口 `--window-demo`：双业务 Window、自动/固定层级、叠加与乱序关闭、穿透计数、输入、导航和第二 Scene 激活。第二 Scene 是否能同时前台显示取决于系统及设备的多任务能力。

`UIApplication.supportsMultipleScenes` 只表明可以支持多个 Scene，不保证每一种设备都允许主动销毁 Scene。当前 Duo 模拟器可激活第二 Scene，但销毁返回 `SBApplicationSupportService` code 1；相关用例明确跳过销毁阶段。iPad 使用真实激活、展示与销毁完成隔离验证，详细结果见验证记录。

布局回归在真实独立 Window 内注入宽/窄宿主 bounds、横竖保留区域及键盘 frame 通知，并切换经典/玻璃材质。它验证坐标计算和配置更新，不代表已操作 iPadOS 所有窄分屏尺寸或实体 Duo 的全部姿态。原有页面 UI 用例使用 `--demo-home` 显式打开首页，防止 Scene 恢复记录改变测试入口。

窗口相关单元测试位于 `Tests/BonePopoverWindowTests`，通过 Demo 托管以获得真实的 `UIWindowScene`；普通 Swift Package 测试 runner 没有业务 Scene。运行时将目标替换为本机可用的模拟器：

```sh
xcodebuild test -project Examples/BonePopoverDemo/BonePopoverDemo.xcodeproj \
  -scheme BonePopoverWindowTests \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -parallel-testing-enabled NO
```

真实点击测试在 `Examples/BonePopoverDemo/UITests/PopoverWindowUITests.swift`，使用 `BonePopoverDemo` scheme。Demo 以 `window-*` 标识统计自身窗口，同时显示 Scene 全部窗口类型；UIKit 的 `UITextEffectsWindow` 等系统窗口不属于 SDK 释放断言。托管测试另行检查窗口/根控制器释放、观察器注销、回调重入和 Scene 清理。

实际执行结果和多 Scene 验证边界见 [Validation.md](Validation.md)。旧管理器的 queue/interrupt/replace/unique、优先级和 identifier 去重属于业务调度能力，本轮未一并实现；可在 App 中协调展示请求。
