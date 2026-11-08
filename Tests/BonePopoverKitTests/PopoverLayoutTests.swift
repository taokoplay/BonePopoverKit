import XCTest
@testable import BonePopoverKit

final class PopoverLayoutTests: XCTestCase {
    func testAsymmetricSafeAreaAndNonZeroOrigin() {
        let context = PopoverLayoutContext(bounds: CGRect(x: 40, y: 20, width: 600, height: 800),
                                           safeAreaInsets: UIEdgeInsets(top: 30, left: 70, bottom: 20, right: 10))
        var layout = PopoverLayout()
        layout.maximumWidth = 1000
        let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                              contentSize: CGSize(width: 300, height: 200))
        XCTAssertEqual(frame, CGRect(x: 122, y: 588, width: 496, height: 200))
    }

    func testBookFoldKeepsDialogInTrailingPaneAndMirrorsForRTL() {
        let hinge = CGRect(x: 390, y: 0, width: 20, height: 700)
        var context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 800, height: 700),
                                           excludedFrames: [hinge])
        var layout = PopoverLayout()
        layout.placement = .center
        let size = CGSize(width: 400, height: 300)
        let ltr = PopoverLayoutEngine.frame(in: context, layout: layout, contentSize: size)
        XCTAssertGreaterThanOrEqual(ltr.minX, hinge.maxX)
        XCTAssertFalse(ltr.intersects(hinge))
        context.isRightToLeft = true
        let rtl = PopoverLayoutEngine.frame(in: context, layout: layout, contentSize: size)
        XCTAssertLessThanOrEqual(rtl.maxX, hinge.minX)
    }

    func testTabletopUsesBottomPaneAndClampsOversizedContent() {
        let hinge = CGRect(x: 0, y: 390, width: 700, height: 20)
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 700, height: 800),
                                           excludedFrames: [hinge])
        let frame = PopoverLayoutEngine.frame(in: context, layout: PopoverLayout(),
                                              contentSize: CGSize(width: 500, height: 1000))
        XCTAssertGreaterThanOrEqual(frame.minY, hinge.maxY)
        XCTAssertLessThanOrEqual(frame.maxY, 800)
        XCTAssertEqual(frame.height, 366)
    }

    func testKeyboardAndCameraAreBothAvoided() {
        let camera = CGRect(x: 0, y: 0, width: 70, height: 70)
        let keyboard = CGRect(x: 0, y: 500, width: 400, height: 300)
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 400, height: 800),
                                           excludedFrames: [camera, keyboard])
        let frame = PopoverLayoutEngine.frame(in: context, layout: PopoverLayout(),
                                              contentSize: CGSize(width: 400, height: 1000))
        XCTAssertFalse(frame.intersects(camera))
        XCTAssertFalse(frame.intersects(keyboard))
        XCTAssertGreaterThan(frame.height, 300)
    }

    func testAnchorSelectsContextualPane() {
        let hinge = CGRect(x: 390, y: 0, width: 20, height: 700)
        let context = PopoverLayoutContext(bounds: CGRect(x: 0, y: 0, width: 800, height: 700),
                                           excludedFrames: [hinge])
        var layout = PopoverLayout()
        layout.anchorPoint = CGPoint(x: 100, y: 200)
        let frame = PopoverLayoutEngine.frame(in: context, layout: layout,
                                              contentSize: CGSize(width: 300, height: 200))
        XCTAssertLessThanOrEqual(frame.maxX, hinge.minX)
    }

    func testResizeRecomputesWithoutScreenCache() {
        let layout = PopoverLayout()
        for width in [CGFloat(300), 600, 1000, 350] {
            let bounds = CGRect(x: 0, y: 0, width: width, height: 700)
            let frame = PopoverLayoutEngine.frame(in: .init(bounds: bounds), layout: layout,
                                                  contentSize: CGSize(width: 800, height: 200))
            XCTAssertEqual(frame.width, min(width - 24, 560))
            XCTAssertTrue(bounds.contains(frame))
        }
    }

    func testFullyOccludedAndTinyContainersNeverProduceNegativeSizes() {
        for bounds in [CGRect(x: 0, y: 0, width: 5, height: 5), .zero] {
            let frame = PopoverLayoutEngine.frame(in: .init(bounds: bounds, excludedFrames: [bounds]),
                                                  layout: PopoverLayout(), contentSize: CGSize(width: 400, height: 400))
            XCTAssertEqual(frame.width, 0)
            XCTAssertEqual(frame.height, 0)
            XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite)
        }
    }
}
