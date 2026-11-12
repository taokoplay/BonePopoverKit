import XCTest
@testable import BonePopoverKit

final class PopoverSurfaceTests: XCTestCase {
    @MainActor
    func testNativeGlassDefinesItsOwnOutlineWithoutClippedAncestors() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Native glass requires iOS 26") }
        let surface = PopoverSurfaceView(frame: CGRect(x: 0, y: 0, width: 340, height: 240))
        var appearance = PopoverAppearance.liquidGlass
        appearance.cornerRadius = 32
        surface.apply(appearance, reduceTransparency: false, customBackground: nil)
        surface.layoutIfNeeded()
        let effect = try XCTUnwrap(surface.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        XCTAssertTrue(effect.effect is UIGlassEffect)
        XCTAssertEqual(effect.cornerConfiguration, .uniformCorners(radius: .fixed(32)))
        XCTAssertFalse(effect.clipsToBounds)
        var ancestor = effect.superview
        while let view = ancestor {
            XCTAssertFalse(view.clipsToBounds, "A parent must not trim the native glass rim")
            XCTAssertNil(view.layer.mask)
            ancestor = view.superview
        }
        XCTAssertFalse(surface.contentContainer.isDescendant(of: effect))
        XCTAssertTrue(surface.subviews.last === surface.contentContainer.superview,
                      "Foreground text must render above, not through, the glass material")
        XCTAssertTrue(surface.contentContainer.superview?.clipsToBounds == true,
                      "Content must still stay within the rounded surface")
        XCTAssertEqual(surface.layer.shadowOpacity, 0)
        XCTAssertNil(surface.layer.shadowPath)
    }

    @MainActor
    func testStyleRoundTripPreservesContentHostAndUpdatesCorners() throws {
        let surface = PopoverSurfaceView(frame: CGRect(x: 0, y: 0, width: 340, height: 240))
        surface.apply(.liquidGlass, reduceTransparency: false, customBackground: nil)
        let effect = try XCTUnwrap(surface.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        let foreground = try XCTUnwrap(surface.contentContainer.superview)
        let textField = UITextField()
        textField.text = "Keep this input"
        surface.contentContainer.addSubview(textField)
        for style in [PopoverAppearance.classic, .frosted, .liquidGlass] {
            var appearance = style
            appearance.cornerRadius = 40
            surface.apply(appearance, reduceTransparency: false, customBackground: nil)
            surface.layoutIfNeeded()
            XCTAssertTrue(effect.superview === surface)
            XCTAssertTrue(surface.contentContainer.superview === foreground)
            XCTAssertTrue(foreground.superview === surface)
            XCTAssertTrue(surface.subviews.last === foreground)
            XCTAssertEqual(textField.text, "Keep this input")
            XCTAssertEqual(surface.contentContainer.frame.size, surface.bounds.size)
            if #available(iOS 26.0, *) {
                XCTAssertEqual(effect.cornerConfiguration, .uniformCorners(radius: .fixed(40)))
            } else {
                XCTAssertEqual(effect.layer.cornerRadius, 40)
            }
        }
        if #available(iOS 26.0, *) { XCTAssertTrue(effect.effect is UIGlassEffect) }
        else { XCTAssertTrue(effect.effect is UIBlurEffect) }
    }

    @MainActor
    func testReducedTransparencyAndCustomBackgroundRestoreOrdinarySurface() throws {
        let surface = PopoverSurfaceView(frame: CGRect(x: 0, y: 0, width: 340, height: 240))
        let appearance = PopoverAppearance.liquidGlass
        surface.apply(appearance, reduceTransparency: true, customBackground: nil)
        surface.layoutIfNeeded()
        let effect = try XCTUnwrap(surface.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        XCTAssertNil(effect.effect)
        XCTAssertEqual(effect.backgroundColor, appearance.backgroundColor)
        XCTAssertTrue(effect.clipsToBounds)
        XCTAssertEqual(surface.layer.shadowOpacity, appearance.shadowOpacity)
        XCTAssertNotNil(surface.layer.shadowPath)
        let custom = UIView()
        surface.apply(appearance, reduceTransparency: false, customBackground: custom)
        surface.layoutIfNeeded()
        XCTAssertNil(effect.effect)
        XCTAssertTrue(custom.superview === effect.contentView)
        XCTAssertEqual(custom.frame, effect.contentView.bounds)
        surface.apply(.classic, reduceTransparency: false, customBackground: nil)
        XCTAssertNil(custom.superview)
        XCTAssertTrue(surface.subviews.last === surface.contentContainer.superview)
    }

    @MainActor
    func testExtraGlassShadowRequiresExplicitOptIn() throws {
        let surface = PopoverSurfaceView(frame: CGRect(x: 0, y: 0, width: 340, height: 240))
        var appearance = PopoverAppearance.liquidGlass
        appearance.addsShadowToLiquidGlass = true
        appearance.shadowOpacity = 0.25
        surface.apply(appearance, reduceTransparency: false, customBackground: nil)
        surface.layoutIfNeeded()
        XCTAssertEqual(surface.layer.shadowOpacity, 0.25)
        XCTAssertNotNil(surface.layer.shadowPath)
        appearance.addsShadowToLiquidGlass = false
        surface.apply(appearance, reduceTransparency: false, customBackground: nil)
        surface.layoutIfNeeded()
        if #available(iOS 26.0, *) {
            XCTAssertEqual(surface.layer.shadowOpacity, 0)
            XCTAssertNil(surface.layer.shadowPath)
        } else {
            XCTAssertEqual(surface.layer.shadowOpacity, 0.25, "Blur fallback retains its configurable shadow")
        }
    }

    /// 阅读器默认样式：纯色表面、顶部两角圆角 16、无遮罩无抓手无阴影、全宽贴底、0.15 秒滑入。
    @MainActor
    func testBottomSheetPresetMatchesReaderDefaults() {
        let sheet = PopoverConfiguration.bottomSheet
        let topCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        if case .solid = sheet.appearance.material {} else {
            XCTFail("bottomSheet should use the solid material of the reader default")
        }
        XCTAssertEqual(sheet.appearance.backgroundColor, .systemBackground)
        XCTAssertEqual(sheet.appearance.cornerRadius, 16)
        XCTAssertEqual(sheet.appearance.maskedCorners, topCorners)
        XCTAssertEqual(sheet.appearance.shadowOpacity, 0)
        XCTAssertFalse(sheet.appearance.showsGrabber)
        XCTAssertFalse(sheet.showsBackdrop)
        XCTAssertEqual(sheet.layout.margins, .zero)
        XCTAssertEqual(sheet.animation.duration, 0.15, accuracy: 0.001)
        // 隐藏端点应为面板整体下移出容器底部。
        let panel = CGRect(x: 0, y: 700, width: 390, height: 200)
        let container = CGRect(x: 0, y: 0, width: 390, height: 900)
        XCTAssertEqual(sheet.animation.hiddenState(panel, container, false).transform.ty,
                       container.maxY - panel.minY, accuracy: 0.001)
        // 其他预设保持通用默认，不被 sheet 样式带偏。
        XCTAssertEqual(PopoverConfiguration.centerDialog.appearance.cornerRadius, 24)
        XCTAssertTrue(PopoverAppearance().maskedCorners.contains(.layerMaxXMaxYCorner))
    }

    /// 非对称圆角需同步作用于前景层与效果层；玻璃退回层裁切，阴影路径按角生成。
    @MainActor
    func testAsymmetricCornersApplyToForegroundEffectAndShadowPath() throws {
        let surface = PopoverSurfaceView(frame: CGRect(x: 0, y: 0, width: 340, height: 240))
        var appearance = PopoverAppearance.classic
        appearance.cornerRadius = 16
        appearance.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        appearance.shadowOpacity = 0.16
        surface.apply(appearance, reduceTransparency: false, customBackground: nil)
        surface.layoutIfNeeded()
        let effect = try XCTUnwrap(surface.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        let foreground = try XCTUnwrap(surface.contentContainer.superview)
        let topCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        XCTAssertEqual(foreground.layer.maskedCorners, topCorners)
        if #available(iOS 26.0, *) {
            XCTAssertEqual(effect.cornerConfiguration,
                           .corners(topLeftRadius: .fixed(16), topRightRadius: .fixed(16),
                                    bottomLeftRadius: nil, bottomRightRadius: nil))
        } else {
            XCTAssertEqual(effect.layer.cornerRadius, 16)
            XCTAssertEqual(effect.layer.maskedCorners, topCorners)
        }
        XCTAssertNotNil(surface.layer.shadowPath)
    }
}
