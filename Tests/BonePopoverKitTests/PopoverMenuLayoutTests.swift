import XCTest
@testable import BonePopoverKit

final class PopoverMenuLayoutTests: XCTestCase {
    func testOpensBelowSourceWhenItFitsEvenIfAboveHasMoreSpace() {
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 400, height: 800))
        let layout = menuLayout(anchor: CGRect(x: 80, y: 480, width: 40, height: 40))
        let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                              contentSize: CGSize(width: 260, height: 200))
        XCTAssertEqual(frame, CGRect(x: 80, y: 528, width: 260, height: 200))
    }

    func testBottomEdgeFlipsAboveSource() {
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 400, height: 800))
        let layout = menuLayout(anchor: CGRect(x: 70, y: 720, width: 60, height: 40))
        let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                              contentSize: CGSize(width: 260, height: 180))
        XCTAssertEqual(frame, CGRect(x: 70, y: 532, width: 260, height: 180))
    }

    func testHorizontalAlignmentAndClampingRespectLayoutDirection() {
        let cases: [(anchor: CGRect, ltrX: CGFloat, rtlX: CGFloat)] = [
            (CGRect(x: 180, y: 100, width: 120, height: 40), 180, 40),
            (CGRect(x: 470, y: 100, width: 40, height: 40), 228, 228),
            (CGRect(x: -40, y: 100, width: 20, height: 40), 12, 12)
        ]
        for item in cases {
            for rtl in [false, true] {
                let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 500, height: 700),
                                                   isRightToLeft: rtl)
                let frame = PopoverLayoutEngine.frame(in: context, layout: menuLayout(anchor: item.anchor),
                                                      contentSize: CGSize(width: 260, height: 120))
                XCTAssertEqual(frame, CGRect(x: rtl ? item.rtlX : item.ltrX, y: 148,
                                              width: 260, height: 120))
                XCTAssertGreaterThanOrEqual(frame.minX, 12)
                XCTAssertLessThanOrEqual(frame.maxX, 488)
            }
        }
    }

    func testNonZeroBoundsAndAsymmetricSafeAreaUseContainerCoordinates() {
        let context = PopoverLayoutContext(bounds: CGRect(x: 40, y: 20, width: 600, height: 800),
                                           safeAreaInsets: UIEdgeInsets(top: 30, left: 70, bottom: 20, right: 10))
        var layout = menuLayout(anchor: CGRect(x: 560, y: 700, width: 30, height: 30))
        layout.margins = UIEdgeInsets(top: 7, left: 11, bottom: 13, right: 17)
        let area = PopoverLayoutEngine.availableFrame(in: context, layout: layout)
        let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                              contentSize: CGSize(width: 260, height: 180))
        XCTAssertEqual(area, CGRect(x: 121, y: 57, width: 492, height: 730))
        XCTAssertEqual(frame, CGRect(x: 353, y: 512, width: 260, height: 180))
        XCTAssertTrue(area.contains(frame))
    }

    func testAnchorRectMidpointKeepsSmallContextualPaneAndOverridesAnchorPoint() {
        let hinge = CGRect(x: 220, y: 0, width: 20, height: 700)
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 1000, height: 700),
                                           excludedFrames: [hinge])
        var layout = menuLayout(anchor: CGRect(x: 60, y: 180, width: 40, height: 30))
        layout.anchorPoint = CGPoint(x: 800, y: 200)
        layout.regionPreference = .trailing
        let smallPane = PopoverLayoutEngine.availableFrame(in: context, layout: layout)
        let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                              contentSize: CGSize(width: 260, height: 120))
        XCTAssertEqual(smallPane, CGRect(x: 12, y: 12, width: 196, height: 676))
        XCTAssertEqual(frame, CGRect(x: 12, y: 218, width: 196, height: 120))
        XCTAssertFalse(frame.intersects(hinge))

        // The origin remains in the small pane, but the rectangle's midpoint is across the hinge.
        layout.anchorRect = CGRect(x: 80, y: 100, width: 360, height: 30)
        layout.anchorPoint = CGPoint(x: 100, y: 200)
        let acrossHinge = PopoverLayoutEngine.frame(in: context, layout: layout,
                                                    contentSize: CGSize(width: 260, height: 120))
        XCTAssertEqual(acrossHinge, CGRect(x: 252, y: 138, width: 260, height: 120))
        XCTAssertFalse(acrossHinge.intersects(hinge))
    }

    func testKeyboardAndLongContentLimitHeightToLargerSide() {
        let keyboard = CGRect(x: 0, y: 500, width: 400, height: 300)
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 400, height: 800),
                                           safeAreaInsets: UIEdgeInsets(top: 20, left: 0, bottom: 34, right: 0),
                                           excludedFrames: [keyboard])
        let cases: [(sourceY: CGFloat, frame: CGRect)] = [
            (340, CGRect(x: 60, y: 32, width: 260, height: 300)),
            (100, CGRect(x: 60, y: 148, width: 260, height: 340))
        ]
        let content = CGSize(width: 260, height: 900)
        for item in cases {
            let layout = menuLayout(anchor: CGRect(x: 60, y: item.sourceY, width: 50, height: 40))
            let frame = PopoverLayoutEngine.frame(in: context, layout: layout, contentSize: content)
            XCTAssertEqual(frame, item.frame)
            XCTAssertFalse(frame.intersects(keyboard))
            XCTAssertGreaterThan(content.height, frame.height, "Overflow must have a smaller visible viewport to scroll.")
            XCTAssertTrue(PopoverLayoutEngine.availableFrame(in: context, layout: layout).contains(frame))
        }
    }

    func testEveryHeightDimensionIsLimitedToTheSideAndRespectsMaximumSize() {
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        let dimensions: [PopoverDimension] = [.content, .fixed(1000), .fill, .fraction(0.9)]
        for height in dimensions {
            var layout = menuLayout(anchor: CGRect(x: 40, y: 220, width: 40, height: 40))
            layout.width = .fixed(600)
            layout.maximumWidth = 180
            layout.height = height
            layout.maximumHeight = 1000
            let limited = PopoverLayoutEngine.frame(in: context, layout: layout,
                                                    contentSize: CGSize(width: 600, height: 1000))
            XCTAssertEqual(limited, CGRect(x: 40, y: 268, width: 180, height: 320))
            layout.maximumHeight = 140
            let capped = PopoverLayoutEngine.frame(in: context, layout: layout,
                                                   contentSize: CGSize(width: 600, height: 1000))
            XCTAssertEqual(capped, CGRect(x: 40, y: 268, width: 180, height: 140))
        }
    }

    func testPointAnchorsAllowZeroSizeAndSanitizeSpacingOnBothSides() {
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        let spacings: [(value: CGFloat, gap: CGFloat)] = [
            (-20, 0), (0, 0), (18, 18), (.nan, 8), (.infinity, 8), (-.infinity, 8)
        ]
        for item in spacings {
            for sourceY in [CGFloat(100), 550] {
                var layout = menuLayout(anchor: CGRect(x: 80, y: sourceY, width: 0, height: 0))
                layout.anchorSpacing = item.value
                let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                                      contentSize: CGSize(width: 260, height: 120))
                let y = sourceY == 100 ? sourceY + item.gap : sourceY - item.gap - 120
                XCTAssertEqual(frame, CGRect(x: 80, y: y, width: 260, height: 120))
            }
        }
    }

    func testMissingOrInvalidAnchorCentersInSelectedPane() {
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 1000, height: 700),
                                           excludedFrames: [CGRect(x: 300, y: 0, width: 20, height: 700)])
        let anchors: [CGRect?] = [
            nil, .null, .infinite,
            CGRect(x: CGFloat.nan, y: 100, width: 40, height: 40),
            CGRect(x: 80, y: CGFloat.nan, width: 40, height: 40),
            CGRect(x: 80, y: 100, width: CGFloat.nan, height: 40),
            CGRect(x: 80, y: 100, width: 40, height: CGFloat.nan),
            CGRect(x: 80, y: 100, width: CGFloat.infinity, height: 40),
            CGRect(x: CGFloat.greatestFiniteMagnitude, y: 100,
                   width: CGFloat.greatestFiniteMagnitude, height: 40)
        ]
        let points: [CGPoint?] = [nil, CGPoint(x: 100, y: 200)]
        for anchor in anchors {
            for point in points {
                var layout = menuLayout(anchor: anchor)
                layout.anchorPoint = point
                let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                                      contentSize: CGSize(width: 260, height: 160))
                let expectedX: CGFloat = point == nil ? 530 : 20
                XCTAssertEqual(frame, CGRect(x: expectedX, y: 270, width: 260, height: 160))
            }
        }
    }

    func testSourceCoveringAreaFallsBackToVisibleCenteredContent() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 600)
        let context = PopoverLayoutContext(bounds: bounds)
        for anchor in [bounds, CGRect(x: -100, y: -100, width: 600, height: 800)] {
            let layout = menuLayout(anchor: anchor)
            let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                                  contentSize: CGSize(width: 260, height: 180))
            XCTAssertEqual(frame, CGRect(x: 70, y: 210, width: 260, height: 180))
            XCTAssertTrue(PopoverLayoutEngine.availableFrame(in: context, layout: layout).contains(frame))
        }
    }

    func testTinyAndFullyOccludedAreasNeverProduceNegativeOrNonfiniteGeometry() {
        let boundsCases = [CGRect.zero, CGRect(x: 30, y: 40, width: 5, height: 5),
                           CGRect(x: 40, y: 20, width: 20, height: 10)]
        let anchors: [CGRect?] = [nil, .null, .infinite, CGRect(x: 50, y: 50, width: 0, height: 0),
                                 CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1)]
        var contexts = boundsCases.flatMap { bounds in
            [PopoverLayoutContext(bounds: bounds),
             PopoverLayoutContext(bounds: bounds, excludedFrames: [bounds])]
        }
        let covered = CGRect(x: 40, y: 20, width: 400, height: 600)
        contexts.append(PopoverLayoutContext(bounds: covered, excludedFrames: [covered]))
        contexts.append(PopoverLayoutContext(bounds: covered,
                                             safeAreaInsets: UIEdgeInsets(top: 400, left: 300, bottom: 400, right: 300)))
        for context in contexts {
            for anchor in anchors {
                let frame = PopoverLayoutEngine.frame(in: context, layout: menuLayout(anchor: anchor),
                                                      contentSize: CGSize(width: 1000, height: 1000))
                XCTAssertEqual(frame.width, 0)
                XCTAssertEqual(frame.height, 0)
                XCTAssertTrue([frame.minX, frame.minY, frame.maxX, frame.maxY,
                               frame.width, frame.height].allSatisfy { $0.isFinite })
            }
        }
    }

    func testAnchorRectDoesNotChangeOtherPlacementsOrAnchorPointPaneSelection() {
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 1000, height: 700),
                                           excludedFrames: [CGRect(x: 300, y: 0, width: 20, height: 700)])
        let cases: [(placement: PopoverPlacement, frame: CGRect)] = [
            (.bottom, CGRect(x: 50, y: 588, width: 200, height: 100)),
            (.top, CGRect(x: 50, y: 12, width: 200, height: 100)),
            (.center, CGRect(x: 50, y: 300, width: 200, height: 100)),
            (.leading, CGRect(x: 12, y: 300, width: 200, height: 100)),
            (.trailing, CGRect(x: 88, y: 300, width: 200, height: 100))
        ]
        for item in cases {
            var layout = menuLayout(anchor: CGRect(x: 800, y: 300, width: 40, height: 40))
            layout.placement = item.placement
            layout.width = .fixed(200)
            layout.anchorPoint = CGPoint(x: 100, y: 300)
            let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                                  contentSize: CGSize(width: 200, height: 100))
            XCTAssertEqual(frame, item.frame)
        }
    }

    @MainActor
    func testMenuPresetDefinesAppearanceAndKeepsOutsideTapAndOverflowDefaults() {
        var configuration = PopoverConfiguration.menu
        guard case .anchored = configuration.layout.placement,
              case .fixed(let width) = configuration.layout.width,
              case .content = configuration.layout.height,
              case .automatic = configuration.appearance.material else {
            return XCTFail("The menu preset must use anchored content layout with an automatic surface.")
        }
        XCTAssertEqual(width, 260)
        XCTAssertEqual(configuration.layout.maximumWidth, 320)
        XCTAssertEqual(configuration.layout.margins, UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        XCTAssertNil(configuration.layout.anchorRect)
        XCTAssertNil(configuration.layout.anchorPoint)
        XCTAssertEqual(configuration.layout.anchorSpacing, 8)
        XCTAssertEqual(configuration.appearance.backgroundColor, .secondarySystemBackground)
        XCTAssertEqual(configuration.appearance.cornerRadius, 14)
        XCTAssertEqual(configuration.appearance.maskedCorners,
                       [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner])
        XCTAssertEqual(configuration.appearance.shadowOpacity, 0.16)
        XCTAssertEqual(configuration.appearance.shadowRadius, 16)
        XCTAssertEqual(configuration.appearance.shadowOffset, CGSize(width: 0, height: 6))
        XCTAssertFalse(configuration.appearance.showsGrabber)
        XCTAssertFalse(configuration.showsBackdrop)
        XCTAssertFalse(configuration.allowsDragToDismiss)
        XCTAssertTrue(configuration.dismissOnBackdropTap)
        XCTAssertFalse(configuration.allowsEventPenetration)
        XCTAssertFalse(configuration.autoHideWhenPenetrated)
        XCTAssertEqual(configuration.allowedSwipeDirections, .automatic)
        XCTAssertEqual(configuration.swipeThreshold, 100)
        XCTAssertTrue(configuration.respectsReduceMotion)
        XCTAssertTrue(configuration.respectsReduceTransparency)
        XCTAssertTrue(configuration.scrollsOverflow)
        XCTAssertEqual(configuration.contentStyle.contentInsets, .zero)
        XCTAssertEqual(configuration.contentStyle.titleFont, .systemFont(ofSize: 13, weight: .semibold))
        XCTAssertEqual(configuration.contentStyle.titleColor, .secondaryLabel)
        XCTAssertEqual(configuration.contentStyle.titleAlignment, .natural)
        XCTAssertEqual(configuration.contentStyle.buttonFont, .systemFont(ofSize: 17))
        XCTAssertEqual(configuration.animation.duration, 0.18)
        XCTAssertEqual(configuration.animation.dampingRatio, 1)
        let hidden = configuration.animation.hiddenState(.zero, .zero, false)
        XCTAssertEqual(hidden.transform, CGAffineTransform(scaleX: 0.96, y: 0.96))
        XCTAssertEqual(hidden.opacity, 0)

        configuration.allowsDragToDismiss = true
        for rtl in [false, true] {
            XCTAssertEqual(configuration.allowedSwipeDirections.resolved(for: configuration.layout.placement,
                                                                          isRightToLeft: rtl), .all)
            XCTAssertEqual(PopoverSwipeDirection.none.resolved(for: .anchored, isRightToLeft: rtl), .none)
            XCTAssertEqual(PopoverSwipeDirection.up.resolved(for: .anchored, isRightToLeft: rtl), .up)
        }
    }

    private func menuLayout(anchor: CGRect?) -> PopoverLayout {
        var layout = PopoverLayout()
        layout.placement = .anchored
        layout.width = .fixed(260)
        layout.maximumWidth = 320
        layout.anchorRect = anchor
        return layout
    }
}
