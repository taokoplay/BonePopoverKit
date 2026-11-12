import UIKit

@MainActor
final class PopoverHostView: UIView, UIGestureRecognizerDelegate {
    weak var popover: BonePopoverView?
    let surface = PopoverSurfaceView()
    let backdrop = UIControl()
    let backdropDimmingView = UIView()
    /// 可选玻璃遮罩：`appearance.backdropGlass` 打开时把身后内容虚化。
    let backdropGlassView = UIVisualEffectView(effect: nil)
    let scrollView = UIScrollView()
    private(set) var panelFrame = CGRect.zero
    private var reservedFrames: [CGRect] = []
    private var keyboardScreenFrame: CGRect?
    private var animator: UIViewPropertyAnimator?
    private var animationGeneration = 0
    private var transitionCompletion: (() -> Void)?
    private var targetVisible = true
    private var hasStarted = false
    private var hasBeenInWindow = false
    private var isInvalidated = false
    private var lastBounds = CGRect.zero
    private struct DragSession {
        let direction: PopoverSwipeDirection
        let initialTransform: CGAffineTransform
        let initialDistance: CGFloat
        let completion: (() -> Void)?
    }
    private var dragSession: DragSession?
    private var dismissalDirection: PopoverSwipeDirection?

    /// 遮罩的默认无障碍标签；BonePopoverView.backdropAccessibilityLabel 可覆盖。
    private static var defaultBackdropLabel: String {
        NSLocalizedString("Dismiss", comment: "Dismiss popover")
    }
    private var dismissalVelocity = CGPoint.zero
    private weak var observedWindow: UIWindow?
    private var navigationGestureGuard: PopoverNavigationGestureGuard?
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    private weak var panTouchView: UIView?
    private lazy var outsideTap = UITapGestureRecognizer(target: self, action: #selector(penetratingTapEnded(_:)))

    override var bounds: CGRect {
        didSet {
            if oldValue.size != bounds.size { setNeedsUpdateConstraints() }
        }
    }

    init(popover: BonePopoverView) {
        self.popover = popover
        super.init(frame: .zero)
        accessibilityViewIsModal = true
        // 独立 Window 使用键盘通知坐标避让，避免 UIKeyboardLayoutGuide 的窗口跟踪持有。
        if popover.windowSession == nil { keyboardLayoutGuide.followsUndockedKeyboard = true }
        addSubview(backdrop)
        // 玻璃层在压暗层下面：先虚化身后内容，再按不透明度压暗。
        backdrop.addSubview(backdropGlassView)
        backdropGlassView.isUserInteractionEnabled = false
        backdrop.addSubview(backdropDimmingView)
        backdropDimmingView.isUserInteractionEnabled = false
        // Keep the input control opaque even when its separate visual layer is clear.
        backdrop.backgroundColor = .clear
        addSubview(surface)
        surface.contentContainer.addSubview(scrollView)
        scrollView.addSubview(popover.view)
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = false
        backdrop.addAction(UIAction { [weak self] _ in self?.backdropTapped() }, for: .touchUpInside)
        backdrop.accessibilityLabel = Self.defaultBackdropLabel
        backdrop.accessibilityTraits = .button
        pan.delegate = self
        surface.addGestureRecognizer(pan)
        outsideTap.delegate = self
        outsideTap.cancelsTouchesInView = false
        outsideTap.delaysTouchesBegan = false
        outsideTap.delaysTouchesEnded = false
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardChanged(_:)),
                           name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardChanged(_:)),
                           name: UIResponder.keyboardWillHideNotification, object: nil)
        for name in [UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                     UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
                     UIAccessibility.reduceMotionStatusDidChangeNotification,
                     UIContentSizeCategory.didChangeNotification] {
            center.addObserver(self, selector: #selector(environmentChanged), name: name, object: nil)
        }
        configurationDidChange()
    }

    required init?(coder: NSCoder) { fatalError("Use init(popover:)") }

    func configurationDidChange() {
        guard !isInvalidated, let popover else { return }
        let configuration = popover.configuration
        popover.applyContentStyle()
        // 界面样式覆盖：`.unspecified` 恢复继承宿主与系统，保持旧行为。
        if overrideUserInterfaceStyle != configuration.interfaceStyle {
            overrideUserInterfaceStyle = configuration.interfaceStyle
        }
        if popover.overrideUserInterfaceStyle != configuration.interfaceStyle {
            popover.overrideUserInterfaceStyle = configuration.interfaceStyle
        }
        surface.apply(configuration.appearance,
                      reduceTransparency: configuration.respectsReduceTransparency && UIAccessibility.isReduceTransparencyEnabled,
                      customBackground: popover.customBackgroundView)
        backdropDimmingView.backgroundColor = configuration.appearance.backdropColor
        applyBackdropGlass(configuration)
        backdrop.isUserInteractionEnabled = !configuration.allowsEventPenetration
        let dismissLabel = popover.backdropAccessibilityLabel
        backdrop.accessibilityLabel = (dismissLabel?.isEmpty == false ? dismissLabel! : Self.defaultBackdropLabel)
        backdrop.isAccessibilityElement = configuration.dismissOnBackdropTap && !configuration.allowsEventPenetration
        accessibilityViewIsModal = !configuration.allowsEventPenetration
        if let session = dragSession {
            dragSession = nil
            if popover.presentationState == .dismissing {
                dismissalDirection = session.direction
            } else {
                transition(visible: true, animated: true, completion: session.completion ?? {})
            }
        } else if animator != nil {
            // Retarget from current visual values so configuration changes made
            // during entry or a snap-back do not leave the old dimming value.
            let completion = transitionCompletion ?? {}
            transition(visible: targetVisible, animated: true, completion: completion)
        } else if popover.presentationState == .presented {
            backdropDimmingView.alpha = backdropOpacity
            backdropGlassView.alpha = backdropGlassActive ? 1 : 0
        }
        pan.isEnabled = configuration.allowsDragToDismiss && !resolvedSwipeDirections.isEmpty
        updateOutsideTapObservation()
        updateNavigationGestureGuard()
        popover.windowSession?.configurationDidChange()
        setNeedsUpdateConstraints()
        setNeedsLayout()
    }

    override func updateConstraints() {
        guard !isInvalidated else { super.updateConstraints(); return }
        reservedFrames = []
        if let popover, popover.configuration.layout.avoidsReservedRegions {
            if let provider = popover.reservedRegionProvider {
                reservedFrames = provider(self)
            } else {
                #if compiler(>=6.4)
                if #available(iOS 27.1, *) {
                    // UIKit tracks these queries here and invalidates constraints when regions change.
                    reservedFrames = (reservedRegions(kind: .division) + reservedRegions(kind: .occlusion))
                        .filter(\.isActive).map(\.frame)
                }
                #endif
            }
        }
        setNeedsLayout()
        super.updateConstraints()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isInvalidated, let popover else { return }
        let config = popover.configuration
        var exclusions = reservedFrames
        if config.layout.avoidsKeyboard, let keyboardScreenFrame, let window {
            exclusions.append(convert(window.convert(keyboardScreenFrame, from: window.screen.coordinateSpace), from: window))
        }
        if config.layout.avoidsKeyboard, popover.windowSession == nil {
            let keyboard = keyboardLayoutGuide.layoutFrame
            if keyboard.height > safeAreaInsets.bottom + 1 {
                exclusions.append(keyboard)
            }
        }
        let context = PopoverLayoutContext(bounds: bounds, safeAreaInsets: safeAreaInsets,
                                           excludedFrames: exclusions,
                                           isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft)
        let available = PopoverLayoutEngine.availableFrame(in: context, layout: config.layout)
        var width = PopoverLayoutEngine.dimension(config.layout.width,
            content: popover.preferredContentSize.width > 0 ? popover.preferredContentSize.width : available.width,
            available: available.width, maximum: config.layout.maximumWidth)
        let grabberHeight: CGFloat = config.appearance.showsGrabber ? 20 : 0
        var measured = popover.preferredPopoverSize(fitting: CGSize(width: width, height: max(0, available.height - grabberHeight)))
        if case .content = config.layout.width {
            width = PopoverLayoutEngine.dimension(.content, content: measured.width,
                available: available.width, maximum: config.layout.maximumWidth)
            measured = popover.preferredPopoverSize(fitting: CGSize(width: width, height: max(0, available.height - grabberHeight)))
        }
        let contentHeight = measured.height.isFinite ? max(0, measured.height) : 300
        let previousFrame = panelFrame
        panelFrame = PopoverLayoutEngine.frame(in: context, layout: config.layout,
            contentSize: CGSize(width: width, height: contentHeight + grabberHeight))
        let resizing = lastBounds != .zero && lastBounds != bounds
        let resume = (resizing || previousFrame != panelFrame) && animator != nil
        let completion = transitionCompletion
        if resume { freezeAnimation() }
        backdrop.frame = bounds
        backdropDimmingView.frame = backdrop.bounds
        backdropGlassView.frame = backdrop.bounds
        surface.bounds = CGRect(origin: .zero, size: panelFrame.size)
        surface.center = CGPoint(x: panelFrame.midX, y: panelFrame.midY)
        surface.layoutIfNeeded()
        scrollView.frame = surface.contentContainer.bounds
        let height = config.scrollsOverflow ? max(scrollView.bounds.height, contentHeight) : scrollView.bounds.height
        popover.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        popover.view.setNeedsLayout()
        popover.view.layoutIfNeeded()
        scrollView.contentSize = CGSize(width: width, height: height)
        scrollView.isScrollEnabled = config.scrollsOverflow && height > scrollView.bounds.height + 1
        lastBounds = bounds
        if resume { transition(visible: targetVisible, animated: true, completion: completion ?? {}) }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsUpdateConstraints()
        setNeedsLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        configurationDidChange()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateOutsideTapObservation()
        updateNavigationGestureGuard()
        if window != nil { hasBeenInWindow = true }
        else if hasBeenInWindow, let popover, popover.presentationState != .dismissing,
                popover.windowSession?.keepsDetachedHost != true {
            popover.dismissPopover(animated: false, reason: .hostRemoved)
        }
    }

    func transition(visible: Bool, animated: Bool, velocity: CGPoint = .zero,
                    completion: @escaping () -> Void) {
        guard let popover else { completion(); return }
        if !visible, let session = dragSession {
            dismissalDirection = session.direction
            dragSession = nil
        }
        freezeAnimation()
        targetVisible = visible
        transitionCompletion = completion
        let config = popover.configuration
        let reducesMotion = config.respectsReduceMotion && UIAccessibility.isReduceMotionEnabled
        let motion = reducesMotion ? PopoverAnimation.fade : config.animation
        let hidden: PopoverVisualState
        if !visible, let direction = dismissalDirection, !reducesMotion {
            hidden = PopoverVisualState(transform: direction.exitTransform(panel: panelFrame, container: bounds))
        } else {
            hidden = motion.hiddenState(panelFrame, bounds, effectiveUserInterfaceLayoutDirection == .rightToLeft)
        }
        if !hasStarted && visible {
            surface.transform = hidden.transform
            surface.alpha = hidden.opacity
            backdropDimmingView.alpha = 0
            backdropGlassView.alpha = 0
        }
        hasStarted = true
        let target = visible ? PopoverVisualState() : hidden
        let duration = animated ? max(0, motion.duration) : 0
        let generation = animationGeneration
        let changes = { [weak self] in
            guard let self else { return }
            self.surface.transform = target.transform
            self.surface.alpha = target.opacity
            self.backdropDimmingView.alpha = visible ? self.backdropOpacity : 0
            // 玻璃只跟开关与可见性走，与压暗不透明度无关。
            self.backdropGlassView.alpha = visible && self.backdropGlassActive ? 1 : 0
        }
        guard duration > 0 else {
            changes()
            transitionCompletion = nil
            completion()
            return
        }
        let dx = target.transform.tx - surface.transform.tx
        let dy = target.transform.ty - surface.transform.ty
        let velocity = visible ? velocity : dismissalVelocity
        let initialVelocity = CGVector(dx: abs(dx) > 1 ? max(-10, min(10, velocity.x / dx)) : 0,
                                       dy: abs(dy) > 1 ? max(-10, min(10, velocity.y / dy)) : 0)
        let timing = UISpringTimingParameters(dampingRatio: motion.dampingRatio, initialVelocity: initialVelocity)
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
        animator.addAnimations(changes)
        animator.addCompletion { [weak self] _ in
            guard let self, self.animationGeneration == generation else { return }
            self.animator = nil
            self.transitionCompletion = nil
            completion()
        }
        self.animator = animator
        animator.startAnimation()
    }

    private func freezeAnimation() {
        animationGeneration += 1
        guard let animator else { return }
        let transform = surface.layer.presentation()?.affineTransform() ?? surface.transform
        let opacity = surface.layer.presentation()?.opacity ?? Float(surface.alpha)
        let backdropOpacity = backdropDimmingView.layer.presentation()?.opacity ?? Float(backdropDimmingView.alpha)
        let glassOpacity = backdropGlassView.layer.presentation()?.opacity ?? Float(backdropGlassView.alpha)
        animator.stopAnimation(true)
        self.animator = nil
        surface.transform = transform
        surface.alpha = CGFloat(opacity)
        backdropDimmingView.alpha = CGFloat(backdropOpacity)
        backdropGlassView.alpha = CGFloat(glassOpacity)
    }

    @objc private func backdropTapped() {
        guard let popover, !popover.configuration.allowsEventPenetration,
              popover.configuration.dismissOnBackdropTap else { return }
        popover.requestDismiss(reason: .penetration)
    }

    private var backdropOpacity: CGFloat {
        guard let config = popover?.configuration, config.showsBackdrop else { return 0 }
        let value = config.appearance.backdropOpacity
        return value.isFinite ? min(1, max(0, value)) : 0
    }

    /// 玻璃遮罩是否生效：受 `showsBackdrop`、`backdropGlass` 与「减弱透明度」共同约束。
    private var backdropGlassActive: Bool {
        guard let config = popover?.configuration, config.showsBackdrop else { return false }
        guard config.appearance.backdropGlass else { return false }
        return !(config.respectsReduceTransparency && UIAccessibility.isReduceTransparencyEnabled)
    }

    /// 玻璃只看开关，不受 `backdropOpacity` 影响：不透明度为 0 时得到纯模糊遮罩。
    private func applyBackdropGlass(_ configuration: PopoverConfiguration) {
        let active = configuration.showsBackdrop && configuration.appearance.backdropGlass
            && !(configuration.respectsReduceTransparency && UIAccessibility.isReduceTransparencyEnabled)
        backdropGlassView.isHidden = !active
        if active {
            backdropGlassView.effect = UIBlurEffect(style: configuration.appearance.backdropGlassStyle)
            if popover?.presentationState == .presented, animator == nil, dragSession == nil {
                backdropGlassView.alpha = 1
            }
        } else {
            backdropGlassView.effect = nil
            backdropGlassView.alpha = 0
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if popover?.configuration.allowsEventPenetration == true,
           !isInsideSurface(point, event: event) { return nil }
        return super.hitTest(point, with: event)
    }

    /// Window 模式复用现有表面命中区域，包括动画中的实际变换。
    func containsPanel(_ point: CGPoint) -> Bool { isInsideSurface(point, event: nil) }

    /// 关闭时明确移除观察，避免等待对象释放才恢复手势或清理触摸观察器。
    func invalidateObservation() {
        guard !isInvalidated else { return }
        isInvalidated = true
        observedWindow?.removeGestureRecognizer(outsideTap)
        observedWindow = nil
        navigationGestureGuard?.invalidate()
        navigationGestureGuard = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func isInsideSurface(_ point: CGPoint, event: UIEvent?) -> Bool {
        surface.point(inside: surface.convert(point, from: self), with: event)
    }

    private func updateNavigationGestureGuard() {
        guard window != nil, let popover, popover.windowSession == nil, !popover.configuration.allowsEventPenetration,
              let presenter = popover.parent,
              let navigation = (presenter as? UINavigationController) ?? presenter.navigationController else {
            navigationGestureGuard?.invalidate()
            navigationGestureGuard = nil
            return
        }
        if navigationGestureGuard == nil {
            navigationGestureGuard = PopoverNavigationGestureGuard(navigationController: navigation)
        }
    }

    private func updateOutsideTapObservation() {
        let enabled = popover.map {
            $0.windowSession == nil && $0.configuration.allowsEventPenetration && $0.configuration.autoHideWhenPenetrated
        } ?? false
        let targetWindow = enabled ? window : nil
        if observedWindow !== targetWindow {
            observedWindow?.removeGestureRecognizer(outsideTap)
            observedWindow = targetWindow
            targetWindow?.addGestureRecognizer(outsideTap)
        }
        outsideTap.isEnabled = enabled
    }

    // Observe real completed taps, never hit-testing queries; the same tap still
    // reaches the underlying button because this recognizer cancels no touches.
    @objc private func penetratingTapEnded(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let popover,
              popover.configuration.allowsEventPenetration,
              popover.configuration.autoHideWhenPenetrated else { return }
        popover.requestDismiss(reason: .penetration)
    }

    @objc private func environmentChanged() {
        configurationDidChange()
    }

    @objc private func keyboardChanged(_ note: Notification) {
        guard let popover, let window,
              (window.isKeyWindow && containsFirstResponder(window)) || keyboardScreenFrame != nil else { return }
        let info = note.userInfo ?? [:]
        let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let local = convert(window.convert(frame, from: window.screen.coordinateSpace), from: window)
        let visible = note.name != UIResponder.keyboardWillHideNotification && bounds.intersects(local)
        keyboardScreenFrame = visible ? frame : nil
        popover.updateKeyboard(frame: frame, visible: visible)
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        setNeedsLayout()
        UIView.animate(withDuration: duration, delay: 0,
                       options: [UIView.AnimationOptions(rawValue: curve << 16), .beginFromCurrentState]) {
            self.layoutIfNeeded()
            if let responder = self.firstResponder(in: popover.view) {
                self.scrollView.scrollRectToVisible(responder.convert(responder.bounds, to: self.scrollView), animated: false)
            }
        }
    }

    private var resolvedSwipeDirections: PopoverSwipeDirection {
        guard let config = popover?.configuration else { return .none }
        return config.allowedSwipeDirections.resolved(for: config.layout.placement,
            isRightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft)
    }

    private func dragDirection(for gesture: UIPanGestureRecognizer) -> PopoverSwipeDirection? {
        let velocity = gesture.velocity(in: self)
        let motion = velocity == .zero ? gesture.translation(in: self) : velocity
        return PopoverSwipeDirection.dominant(in: motion, allowed: resolvedSwipeDirections)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === outsideTap {
            return popover?.presentationState == .presented || popover?.presentationState == .presenting
        }
        guard gestureRecognizer === pan else { return super.gestureRecognizerShouldBegin(gestureRecognizer) }
        defer { panTouchView = nil }
        guard let popover, popover.configuration.allowsDragToDismiss,
              popover.presentationState == .presented || popover.presentationState == .presenting,
              let direction = dragDirection(for: pan) else { return false }
        // Use the original touched view, even if the finger has since moved
        // outside its scrolling area before the pan reaches its start threshold.
        var hit = panTouchView ?? surface.hitTest(pan.location(in: surface), with: nil)
        while let view = hit, view !== surface {
            if let scroll = view as? UIScrollView, !direction.canTakeOver(scroll) { return false }
            hit = view.superview
        }
        return popover.shouldBeginSwipeToDismiss(pan)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === outsideTap || otherGestureRecognizer === outsideTap { return true }
        guard gestureRecognizer === pan else { return false }
        return popover?.shouldRecognizeSwipeToDismissSimultaneously(with: otherGestureRecognizer) ?? false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === outsideTap {
            let point = touch.location(in: self)
            return bounds.contains(point) && !isInsideSurface(point, event: nil)
        }
        var view = touch.view
        while let current = view, current !== surface {
            if current is UIControl { return false }
            view = current.superview
        }
        if gestureRecognizer === pan { panTouchView = touch.view }
        return true
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let popover,
              popover.presentationState == .presented || popover.presentationState == .presenting else {
            dragSession = nil
            return
        }
        if gesture.state == .began {
            guard popover.configuration.allowsDragToDismiss,
                  let direction = dragDirection(for: gesture) else { return }
            let completion = transitionCompletion
            freezeAnimation()
            let distance = max(0, direction.projection(of: CGPoint(x: surface.transform.tx, y: surface.transform.ty)))
            dragSession = DragSession(direction: direction, initialTransform: surface.transform,
                initialDistance: distance, completion: completion)
            return
        }
        guard let session = dragSession else { return }
        let direction = session.direction
        let velocity = gesture.velocity(in: self)
        let distance = max(0, session.initialDistance + direction.projection(of: gesture.translation(in: self)))
        switch gesture.state {
        case .changed:
            var transform = session.initialTransform
            transform.tx += direction.vector.x * (distance - session.initialDistance)
            transform.ty += direction.vector.y * (distance - session.initialDistance)
            surface.transform = transform
            let extent = max(1, direction.vector.x == 0 ? panelFrame.height : panelFrame.width)
            backdropDimmingView.alpha = backdropOpacity * max(0, 1 - distance / extent)
            backdropGlassView.alpha = backdropGlassActive ? max(0, 1 - distance / extent) : 0
        case .ended, .cancelled, .failed:
            let outwardVelocity = direction.projection(of: velocity)
            let configuredThreshold = popover.configuration.swipeThreshold
            let threshold = configuredThreshold.isFinite ? max(0, configuredThreshold) : 100
            let shouldFinish = gesture.state == .ended && outwardVelocity >= -100
                && distance + outwardVelocity * 0.15 > threshold
            if shouldFinish {
                dismissalDirection = direction
                dismissalVelocity = velocity
                if popover.requestDismiss(reason: .slide) { return }
                // A business veto may itself have begun a programmatic dismissal.
                // Never replace its cleanup completion with a snap-back.
                guard popover.presentationState == .presented || popover.presentationState == .presenting else { return }
                dismissalDirection = nil
                dismissalVelocity = .zero
            }
            dragSession = nil
            transition(visible: true, animated: true, velocity: velocity, completion: session.completion ?? {})
        default: break
        }
    }

    private func containsFirstResponder(_ view: UIView) -> Bool { firstResponder(in: view) != nil }

    private func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        return view.subviews.lazy.compactMap { self.firstResponder(in: $0) }.first
    }
}
