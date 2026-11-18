import XCTest
@testable import BonePopoverKit

final class PopoverMenuWindowTests: XCTestCase {
    @MainActor
    func testMenuConvertsSourceAnchorIntoItsOwnWindowAndReleasesWindowOnDismiss() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let source = UIWindow(windowScene: scene)
        let presenter = UIViewController()
        source.rootViewController = presenter
        source.makeKeyAndVisible()
        presenter.view.layoutIfNeeded()
        let container = UIView(frame: CGRect(x: 32, y: 140, width: 280, height: 200))
        let button = UIButton(frame: CGRect(x: 16, y: 24, width: 100, height: 44))
        container.addSubview(button)
        presenter.view.addSubview(container)
        let menu = BoneMenuView(anchorView: button)
        menu.reservedRegionProvider = { _ in [] }
        menu.addItem(title: "分享")
        XCTAssertTrue(menu.show(over: source, animated: false))
        defer { menu.dismissPopover(animated: false); source.isHidden = true }
        let host = try XCTUnwrap(menu.presentationHost)
        let session = try XCTUnwrap(menu.windowSession)
        host.layoutIfNeeded()
        XCTAssertFalse(menu.view.window === source)
        XCTAssertTrue(menu.view.window?.windowScene === scene)
        let anchor = button.convert(button.bounds, to: host)
        XCTAssertEqual(host.panelFrame.minX, anchor.minX, accuracy: 1)
        XCTAssertEqual(host.panelFrame.minY, anchor.maxY + 8, accuracy: 1)
        menu.dismissPopover(animated: false)
        XCTAssertTrue(session.window.isHidden)
        XCTAssertNil(session.window.rootViewController)
        XCTAssertNil(menu.presentationHost)
        XCTAssertTrue(source.isKeyWindow)
        XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: scene).isEmpty)
    }
}
