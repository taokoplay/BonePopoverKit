import XCTest
@testable import BonePopoverKit

final class PopoverAlertButtonTests: XCTestCase {
    @MainActor
    private func present(width: CGFloat = 390, input: Bool = false,
                         configure: (BoneAlertView) -> Void = { _ in }) throws
        -> (UIWindow, UIViewController, BoneAlertView, PopoverHostView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 900))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.isHidden = false
        presenter.view.frame = window.bounds
        let alert = input
            ? BoneAlertView(title: "输入", placeholder: "名称") { _ in }
            : BoneAlertView(title: "确认", message: "说明") {}
        configure(alert)
        XCTAssertTrue(alert.show(from: presenter, animated: false))
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        host.layoutIfNeeded()
        return (window, presenter, alert, host)
    }

    @MainActor
    private func assertRow(_ alert: BoneAlertView, file: StaticString = #filePath, line: UInt = #line) {
        let cancel = alert.cancelButton.convert(alert.cancelButton.bounds, to: alert.baseView)
        let confirm = alert.confirmButton.convert(alert.confirmButton.bounds, to: alert.baseView)
        XCTAssertEqual(cancel.minX, 24, accuracy: 1, file: file, line: line)
        XCTAssertEqual(confirm.maxX, alert.baseView.bounds.width - 24, accuracy: 1, file: file, line: line)
        XCTAssertEqual(cancel.width, confirm.width, accuracy: 1, file: file, line: line)
        XCTAssertEqual(cancel.minY, confirm.minY, accuracy: 1, file: file, line: line)
        XCTAssertEqual(confirm.minX - cancel.maxX, 12, accuracy: 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(confirm.height, 44, file: file, line: line)
    }

    @MainActor
    private func assertColumn(_ alert: BoneAlertView, file: StaticString = #filePath, line: UInt = #line) {
        let cancel = alert.cancelButton.convert(alert.cancelButton.bounds, to: alert.baseView)
        let confirm = alert.confirmButton.convert(alert.confirmButton.bounds, to: alert.baseView)
        XCTAssertEqual(cancel.minX, 24, accuracy: 1, file: file, line: line)
        XCTAssertEqual(confirm.minX, 24, accuracy: 1, file: file, line: line)
        XCTAssertEqual(cancel.maxX, alert.baseView.bounds.width - 24, accuracy: 1, file: file, line: line)
        XCTAssertEqual(confirm.width, cancel.width, accuracy: 1, file: file, line: line)
        XCTAssertEqual(cancel.minY - confirm.maxY, 12, accuracy: 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(confirm.height, 44, file: file, line: line)
    }

    @MainActor
    func testConfirmationAndInputDefaultToEqualWidthHorizontalButtons() throws {
        for width in [CGFloat(390), 1024] {
            for input in [false, true] {
                let (window, _, alert, _) = try present(width: width, input: input)
                defer { window.isHidden = true }
                XCTAssertEqual(alert.buttonLayout, .automatic)
                assertRow(alert)
                alert.dismissPopover(animated: false)
            }
        }
    }

    @MainActor
    func testAutomaticUsesColumnForNarrowSpaceAndLongButtonTitles() throws {
        let (narrowWindow, _, narrow, _) = try present(width: 240)
        defer { narrowWindow.isHidden = true }
        assertColumn(narrow)
        narrow.dismissPopover(animated: false)
        let (window, _, alert, _) = try present { alert in
            alert.loadViewIfNeeded()
            alert.confirmButton.configuration?.title = "确认并继续处理全部选项"
        }
        defer { window.isHidden = true }
        assertColumn(alert)
        alert.dismissPopover(animated: false)
    }

    @MainActor
    func testManualLayoutChangesRelayoutHeightAndCanReturnToAutomatic() throws {
        let (window, _, alert, host) = try present()
        defer { window.isHidden = true }
        let rowHeight = host.panelFrame.height
        assertRow(alert)
        alert.buttonLayout = .vertical
        host.layoutIfNeeded()
        assertColumn(alert)
        XCTAssertGreaterThan(host.panelFrame.height, rowHeight + 40)
        alert.buttonLayout = .horizontal
        host.layoutIfNeeded()
        assertRow(alert)
        XCTAssertEqual(host.panelFrame.height, rowHeight, accuracy: 1)
        alert.buttonLayout = .automatic
        host.layoutIfNeeded()
        assertRow(alert)
        alert.dismissPopover(animated: false)
    }

    @MainActor
    func testAccessibilityCategoryUsesColumnAndRestoresRowWhenReset() throws {
        let (window, presenter, alert, host) = try present()
        defer { window.isHidden = true }
        presenter.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
                                             forChild: alert)
        alert.invalidatePopoverLayout()
        host.layoutIfNeeded()
        assertColumn(alert)
        presenter.setOverrideTraitCollection(nil, forChild: alert)
        alert.invalidatePopoverLayout()
        host.layoutIfNeeded()
        assertRow(alert)
        alert.dismissPopover(animated: false)
    }

    @MainActor
    func testFoldedPaneUsesColumnAndUnfoldingRestoresRow() throws {
        let (window, _, alert, host) = try present(width: 800)
        defer { window.isHidden = true }
        assertRow(alert)
        alert.configuration.layout.anchorPoint = CGPoint(x: 100, y: 100)
        alert.reservedRegionProvider = { view in
            [CGRect(x: 190, y: 0, width: 20, height: view.bounds.height)]
        }
        host.layoutIfNeeded()
        assertColumn(alert)
        XCTAssertLessThanOrEqual(host.panelFrame.maxX, 190)
        alert.reservedRegionProvider = { _ in [] }
        host.layoutIfNeeded()
        assertRow(alert)
        alert.dismissPopover(animated: false)
    }
}
