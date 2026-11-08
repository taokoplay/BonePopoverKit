import XCTest
@testable import BonePopoverKit

final class PopoverAlertSizingTests: XCTestCase {
    @MainActor
    func testConfirmationAndInputShareLargerMarginsAndFiniteMaximumSize() {
        let alerts = [BoneAlertView(title: "确认", message: "正文") {},
                      BoneAlertView(title: "输入", placeholder: "文本") { _ in }]
        for alert in alerts {
            XCTAssertEqual(alert.horizontalMargin, 32)
            XCTAssertEqual(alert.configuration.layout.margins.right, 32)
            XCTAssertEqual(alert.maximumSize, CGSize(width: 420, height: 600))
            XCTAssertEqual(alert.configuration.layout.margins.top, 12)
            XCTAssertEqual(alert.configuration.layout.margins.bottom, 12)
        }
        XCTAssertFalse(alerts[1].configuration.dismissOnBackdropTap)
        XCTAssertEqual(PopoverConfiguration.centerDialog.layout.margins.left, 12,
                       "The generic preset must keep its existing spacing")
    }

    @MainActor
    func testMaximumSizeAndMarginsClampToEachAvailableContainer() {
        let alert = BoneAlertView(title: "尺寸", message: "正文") {}
        let cases: [(CGSize, CGSize)] = [
            (CGSize(width: 1366, height: 1024), CGSize(width: 420, height: 600)),
            (CGSize(width: 390, height: 844), CGSize(width: 326, height: 600)),
            (CGSize(width: 280, height: 300), CGSize(width: 216, height: 276))
        ]
        for (container, expected) in cases {
            let frame = PopoverLayoutEngine.frame(in: .init(bounds: CGRect(origin: .zero, size: container)),
                layout: alert.configuration.layout, contentSize: CGSize(width: 2000, height: 2000))
            XCTAssertEqual(frame.size, expected)
            XCTAssertGreaterThanOrEqual(frame.minX, 32)
            XCTAssertLessThanOrEqual(frame.maxX, container.width - 32)
        }
    }

    @MainActor
    func testLiveSizingChangesKeepOverflowScrollableAndRespectFoldedPane() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.isHidden = false
        defer { window.isHidden = true }
        presenter.view.frame = window.bounds
        let alert = BoneAlertView(title: "尺寸设置", message: "可见时调整尺寸") {}
        alert.preferredContentSize = CGSize(width: 400, height: 2000)
        XCTAssertTrue(alert.show(from: presenter, animated: false))
        defer { alert.dismissPopover(animated: false) }
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        XCTAssertEqual(host.panelFrame.size, CGSize(width: 420, height: 600))
        XCTAssertTrue(host.scrollView.isScrollEnabled)
        alert.horizontalMargin = 48
        alert.maximumSize = CGSize(width: 320, height: 280)
        host.layoutIfNeeded()
        XCTAssertEqual(host.panelFrame.size, CGSize(width: 320, height: 280))
        XCTAssertEqual(alert.view.bounds.width, 320)
        XCTAssertEqual(host.scrollView.bounds.height, 280)
        alert.reservedRegionProvider = { view in
            [CGRect(x: view.bounds.midX - 10, y: 0, width: 20, height: view.bounds.height)]
        }
        host.layoutIfNeeded()
        XCTAssertLessThanOrEqual(host.panelFrame.width, 194)
        XCTAssertFalse(host.panelFrame.intersects(CGRect(x: 290, y: 0, width: 20, height: 800)))
        XCTAssertTrue(host.scrollView.isScrollEnabled)
        let cancel = alert.cancelButton.convert(alert.cancelButton.bounds, to: host.scrollView)
        XCTAssertTrue(host.scrollView.contentSize.height >= cancel.maxY)
    }

    @MainActor
    func testConveniencePropertiesTrackTheUnderlyingLayoutConfiguration() {
        let alert = BoneAlertView(title: "配置", message: "正文") {}
        alert.configuration = .centerDialog
        XCTAssertEqual(alert.horizontalMargin, 12)
        alert.horizontalMargin = 40
        alert.maximumSize = CGSize(width: 500, height: 450)
        XCTAssertEqual(alert.configuration.layout.margins.left, 40)
        XCTAssertEqual(alert.configuration.layout.margins.right, 40)
        XCTAssertEqual(alert.configuration.layout.maximumWidth, 500)
        XCTAssertEqual(alert.configuration.layout.maximumHeight, 450)
        alert.configuration.layout.maximumWidth = 360
        XCTAssertEqual(alert.maximumSize.width, 360)
    }
}
