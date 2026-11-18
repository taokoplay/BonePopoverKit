import XCTest
@testable import BonePopoverKit

final class PopoverMenuTests: XCTestCase {
    @MainActor
    private func source() -> (UIWindow, UIViewController, UIButton) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 900))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.view.frame = window.bounds
        let container = UIView(frame: CGRect(x: 30, y: 100, width: 330, height: 750))
        let button = UIButton(frame: CGRect(x: 16, y: 20, width: 100, height: 44))
        container.addSubview(button)
        presenter.view.addSubview(container)
        presenter.view.layoutIfNeeded()
        return (window, presenter, button)
    }

    @MainActor
    private func present(_ menu: BoneMenuView, from presenter: UIViewController) throws -> PopoverHostView {
        menu.reservedRegionProvider = { _ in [] }
        XCTAssertTrue(menu.show(from: presenter, animated: false))
        let host = try XCTUnwrap(menu.presentationHost)
        host.layoutIfNeeded()
        return host
    }

    @MainActor
    private func row(_ row: Int, section: Int = 0, in menu: BoneMenuView) throws -> UITableViewCell {
        menu.tableView.layoutIfNeeded()
        let cell = try XCTUnwrap(menu.tableView.cellForRow(at: IndexPath(row: row, section: section)))
        cell.layoutIfNeeded()
        return cell
    }

    @MainActor
    private func descendants<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(of: type, in: $0) }
    }

    @MainActor
    func testGroupsMergeByTitleAndRowsCarryIconsStylesAndAccessibility() throws {
        let (window, presenter, button) = source()
        let menu = BoneMenuView(anchorView: button)
        let original = try XCTUnwrap(UIImage(systemName: "star")).withRenderingMode(.alwaysOriginal)
        menu.addItem(title: "收藏", icon: original, isSelected: true, inSection: "阅读")
        menu.addItem(title: "删除", icon: UIImage(systemName: "trash"), style: .destructive,
                     inSection: "操作", accessibilityIdentifier: "delete-book")
        menu.addItem(title: "朗读", isEnabled: false, inSection: "阅读")
        menu.addItem(title: "分享", style: .highlighted, inSection: "操作")
        menu.configuration.contentStyle.adjustsFontForContentSizeCategory = false
        menu.loadViewIfNeeded()
        menu.view.tintColor = .systemPurple
        let host = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }

        XCTAssertEqual(menu.tableView.numberOfSections, 2)
        XCTAssertEqual(menu.tableView.numberOfRows(inSection: 0), 2)
        XCTAssertEqual(menu.tableView.numberOfRows(inSection: 1), 2)
        let favorite = try row(0, in: menu)
        let favoriteContent = try XCTUnwrap(favorite.contentConfiguration as? UIListContentConfiguration)
        XCTAssertEqual(favoriteContent.text, "收藏")
        XCTAssertEqual(favoriteContent.image, original)
        XCTAssertEqual(favorite.accessoryType, .checkmark)
        XCTAssertTrue(favorite.accessibilityTraits.contains(.selected))
        XCTAssertEqual(favorite.accessibilityIdentifier, "menu-item-0-0")
        let disabled = try row(1, in: menu)
        XCTAssertFalse(disabled.isUserInteractionEnabled)
        XCTAssertTrue(disabled.accessibilityTraits.contains(.notEnabled))
        XCTAssertNil(menu.tableView(menu.tableView, willSelectRowAt: IndexPath(row: 1, section: 0)))
        let deletion = try row(0, section: 1, in: menu)
        let deletionContent = try XCTUnwrap(deletion.contentConfiguration as? UIListContentConfiguration)
        XCTAssertEqual(deletion.accessibilityIdentifier, "delete-book")
        XCTAssertEqual(deletionContent.textProperties.color, .systemRed)
        XCTAssertEqual(deletionContent.image?.renderingMode, .alwaysTemplate)
        let highlight = try row(1, section: 1, in: menu)
        XCTAssertEqual((highlight.contentConfiguration as? UIListContentConfiguration)?.textProperties.color, .systemPurple)
        let header = try XCTUnwrap(menu.tableView(menu.tableView, viewForHeaderInSection: 0))
        XCTAssertEqual(descendants(of: UILabel.self, in: header).first?.text, "阅读")

        menu.addItem(title: "稍后阅读", inSection: "阅读")
        host.layoutIfNeeded()
        XCTAssertEqual(menu.tableView.numberOfRows(inSection: 0), 3)
        XCTAssertEqual(try row(2, in: menu).accessibilityLabel, "稍后阅读")
    }

    @MainActor
    func testStateUpdatesWhileVisibleAndDisabledItemsNeverInvokeCallbacks() throws {
        let (window, presenter, button) = source()
        let menu = BoneMenuView(anchorView: button)
        var calls = 0
        menu.addItem(title: "切换", isEnabled: false, dismissesPopover: false) { calls += 1 }
        let host = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }
        let path = IndexPath(row: 0, section: 0)
        menu.tableView(menu.tableView, didSelectRowAt: path)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(menu.presentationState, .presented)
        menu.setItemEnabled(true, at: path)
        menu.setItemSelected(true, at: path)
        host.layoutIfNeeded()
        let enabled = try row(0, in: menu)
        XCTAssertTrue(enabled.isUserInteractionEnabled)
        XCTAssertEqual(enabled.accessoryType, .checkmark)
        XCTAssertTrue(enabled.accessibilityTraits.contains(.selected))
        menu.tableView(menu.tableView, didSelectRowAt: path)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(menu.presentationState, .presented)
        menu.setItemSelected(false, at: path)
        menu.setItemEnabled(false, at: path)
        // 越界更新可安全忽略。
        menu.setItemEnabled(true, at: IndexPath(row: -1, section: 4))
        host.layoutIfNeeded()
        XCTAssertEqual(try row(0, in: menu).accessoryType, .none)
        menu.tableView(menu.tableView, didSelectRowAt: path)
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testDefaultCallbackWaitsForDismissalAndCanPresentAgainWithoutDuplicateDelivery() async throws {
        let (window, presenter, button) = source()
        let menu = BoneMenuView(anchorView: button)
        menu.configuration.animation = .fade
        let called = expectation(description: "menu action after dismissal")
        var calls = 0
        menu.addItem(title: "打开") { [weak menu] in
            guard let menu else { return }
            XCTAssertEqual(menu.presentationState, .hidden)
            XCTAssertNil(menu.presentationHost)
            calls += 1
            XCTAssertTrue(menu.show(from: presenter, animated: false))
            called.fulfill()
        }
        _ = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }
        let path = IndexPath(row: 0, section: 0)
        menu.tableView(menu.tableView, didSelectRowAt: path)
        XCTAssertEqual(menu.presentationState, .dismissing)
        XCTAssertEqual(calls, 0)
        menu.tableView(menu.tableView, didSelectRowAt: path)
        await fulfillment(of: [called], timeout: 3)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(menu.presentationState, .presented)
    }

    @MainActor
    func testAnchorUsesNestedCoordinatesAndRecalculatesAfterSourceMoves() throws {
        let (window, presenter, button) = source()
        let menu = BoneMenuView(anchorView: button)
        for index in 0..<3 { menu.addItem(title: "操作 \(index)") }
        let host = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }
        var anchor = button.convert(button.bounds, to: host)
        XCTAssertEqual(host.panelFrame.minX, anchor.minX, accuracy: 0.5)
        XCTAssertEqual(host.panelFrame.minY, anchor.maxY + 8, accuracy: 0.5)
        button.frame.origin.y = 620
        menu.invalidatePopoverLayout()
        host.layoutIfNeeded()
        anchor = button.convert(button.bounds, to: host)
        XCTAssertEqual(host.panelFrame.maxY, anchor.minY - 8, accuracy: 0.5)
        XCTAssertFalse(menu.tableView.isScrollEnabled)
        XCTAssertEqual(menu.view.bounds.size, host.scrollView.bounds.size)
    }

    @MainActor
    func testLocalRectCanChangeAndNilRestoresCurrentSourceBounds() throws {
        let (window, presenter, button) = source()
        let initial = CGRect(x: 8, y: 4, width: 30, height: 12)
        let menu = BoneMenuView(anchorRect: initial, in: button)
        menu.addItem(title: "局部菜单")
        let host = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(host.panelFrame.minY, button.convert(initial, to: host).maxY + 8, accuracy: 0.5)
        let updated = CGRect(x: 2, y: 20, width: 10, height: 10)
        menu.updateAnchorRect(updated)
        host.layoutIfNeeded()
        XCTAssertEqual(host.panelFrame.minX, button.convert(updated, to: host).minX, accuracy: 0.5)
        XCTAssertEqual(host.panelFrame.minY, button.convert(updated, to: host).maxY + 8, accuracy: 0.5)
        menu.updateAnchorRect(nil)
        button.bounds.size.height = 60
        host.layoutIfNeeded()
        XCTAssertEqual(host.panelFrame.minY, button.convert(button.bounds, to: host).maxY + 8, accuracy: 0.5)
    }

    @MainActor
    func testLongMenuScrollsInsideItsCappedViewportAndReachesLastAction() throws {
        let (window, presenter, button) = source()
        let menu = BoneMenuView(anchorView: button)
        menu.configuration.layout.maximumHeight = 240
        menu.configuration.animation = .none
        var selected: Int?
        for index in 0..<30 {
            menu.addItem(title: "项目 \(index)") { selected = index }
        }
        let host = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(host.panelFrame.height, 240, accuracy: 1)
        XCTAssertFalse(host.scrollView.isScrollEnabled)
        XCTAssertTrue(menu.tableView.isScrollEnabled)
        XCTAssertGreaterThan(menu.tableView.contentSize.height, menu.tableView.bounds.height * 3)
        let last = IndexPath(row: 29, section: 0)
        menu.tableView.scrollToRow(at: last, at: .bottom, animated: false)
        menu.tableView.layoutIfNeeded()
        let lastCell = try row(29, in: menu)
        XCTAssertTrue(menu.tableView.bounds.intersects(lastCell.frame))
        menu.tableView(menu.tableView, didSelectRowAt: last)
        XCTAssertEqual(selected, 29)
        XCTAssertEqual(menu.presentationState, .hidden)
    }

    @MainActor
    func testFractionalWidthMeasuresWrappedTextAtFinalWidthWithoutDoubleScaling() throws {
        let (window, presenter, button) = source()
        let menu = BoneMenuView(anchorView: button)
        menu.configuration.layout.width = .fraction(0.75)
        menu.configuration.contentStyle.adjustsFontForContentSizeCategory = false
        menu.addItem(title: "包含图标与选中标记的长菜单项目，应完整换行显示文字", icon: UIImage(systemName: "star"), isSelected: true)
        let host = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }
        let cell = try row(0, in: menu)
        let label = try XCTUnwrap(descendants(of: UILabel.self, in: cell).first)
        XCTAssertEqual(menu.tableView.bounds.width, host.panelFrame.width, accuracy: 0.5)
        let measured = menu.preferredPopoverSize(fitting: host.panelFrame.size)
        XCTAssertEqual(measured.width, host.panelFrame.width, accuracy: 0.5)
        XCTAssertEqual(measured.height, cell.bounds.height, accuracy: 1)
        let textSize = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        XCTAssertGreaterThan(label.bounds.height, label.font.lineHeight * 1.5)
        XCTAssertGreaterThanOrEqual(label.bounds.height + 1, textSize.height, "实际标签应能显示完整文案")
    }

    @MainActor
    func testFontsAndPaddingRefreshRowsAndDynamicTypeGrowsHeight() throws {
        let (window, presenter, button) = source()
        let menu = BoneMenuView(anchorView: button)
        menu.addItem(title: "随系统字号变化的菜单", inSection: "分组")
        menu.configuration.contentStyle.adjustsFontForContentSizeCategory = false
        let host = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }
        let originalHeight = try row(0, in: menu).bounds.height
        menu.configuration.contentStyle.buttonFont = .systemFont(ofSize: 24, weight: .semibold)
        menu.configuration.contentStyle.buttonContentInsets = NSDirectionalEdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20)
        host.layoutIfNeeded()
        let custom = try row(0, in: menu)
        let customContent = try XCTUnwrap(custom.contentConfiguration as? UIListContentConfiguration)
        XCTAssertEqual(customContent.textProperties.font.pointSize, 24, accuracy: 0.1)
        XCTAssertEqual(customContent.directionalLayoutMargins.top, 18)
        XCTAssertGreaterThan(custom.bounds.height, originalHeight)
        let customHeight = custom.bounds.height
        presenter.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge), forChild: menu)
        menu.configuration.contentStyle.adjustsFontForContentSizeCategory = true
        host.layoutIfNeeded()
        let large = try row(0, in: menu)
        let largeContent = try XCTUnwrap(large.contentConfiguration as? UIListContentConfiguration)
        XCTAssertGreaterThan(largeContent.textProperties.font.pointSize, 24)
        XCTAssertGreaterThan(large.bounds.height, customHeight)
    }

    @MainActor
    func testClearBackdropStillBlocksOutsideTouchesAndDismissesWithoutAction() throws {
        let (window, presenter, button) = source()
        let menu = BoneMenuView(anchorView: button)
        var actionCalls = 0
        menu.addItem(title: "分享") { actionCalls += 1 }
        menu.configuration.animation = .none
        let host = try present(menu, from: presenter)
        defer { menu.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertFalse(menu.configuration.showsBackdrop)
        XCTAssertEqual(host.backdropDimmingView.alpha, 0)
        XCTAssertTrue(host.backdrop.isUserInteractionEnabled)
        XCTAssertTrue(host.hitTest(CGPoint(x: host.bounds.maxX - 2, y: host.bounds.maxY - 2), with: nil) === host.backdrop)
        host.backdrop.sendActions(for: .touchUpInside)
        XCTAssertEqual(menu.presentationState, .hidden)
        XCTAssertEqual(actionCalls, 0)
    }
}
