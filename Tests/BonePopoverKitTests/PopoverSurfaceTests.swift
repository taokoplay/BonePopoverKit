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
}
