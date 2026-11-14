import XCTest
@testable import BonePopoverKit

/// 操作列表的增量写法：先建面板，再逐个 addButton 添加表格行。
final class PopoverOperationListBuilderTests: XCTestCase {
    @MainActor
    private func present(_ popover: BonePopoverView, width: CGFloat = 390) throws
        -> (UIWindow, UIViewController, PopoverHostView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 900))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.view.frame = window.bounds
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        let host = try XCTUnwrap(popover.presentationHost)
        host.layoutIfNeeded()
        return (window, presenter, host)
    }

    @MainActor
    private func descendants<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? [])
            + view.subviews.flatMap { descendants(of: type, in: $0) }
    }

    @MainActor
    private func row(_ index: Int, in sheet: BoneDrawerSheetView) throws -> UITableViewCell {
        sheet.tableView.layoutIfNeeded()
        let cell = try XCTUnwrap(sheet.tableView.cellForRow(at: IndexPath(row: index, section: 0)))
        XCTAssertTrue(cell is BoneDrawerSheetCell)
        cell.layoutIfNeeded()
        return cell
    }

    /// 加载前后均可增量添加；只展示业务行，不自动追加取消行。
    @MainActor
    func testSheetAddsRowsInOrderWithoutAnExtraCancelRow() throws {
        let sheet = BoneDrawerSheetView(title: "项目操作", message: "选择要执行的操作")
        let image = try XCTUnwrap(UIImage(systemName: "square.and.arrow.up"))
            .withRenderingMode(.alwaysOriginal)
        sheet.addButton(text: "分享", icon: image)
        sheet.addButton(text: "删除", style: .destructive, accessibilityIdentifier: "delete-project")
        sheet.sheetConfig.highlightColor = .systemPurple

        let (window, _, host) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(sheet.tableView.style, .grouped)
        XCTAssertEqual(sheet.tableView.numberOfSections, 1)
        XCTAssertEqual(sheet.tableView.numberOfRows(inSection: 0), 2)
        XCTAssertTrue(sheet.trailingButton.isHidden)
        XCTAssertFalse(sheet.closeButton.isHidden)

        let share = try row(0, in: sheet)
        let remove = try row(1, in: sheet)
        XCTAssertEqual(share.accessibilityIdentifier, "drawer-row-0-0")
        XCTAssertEqual(remove.accessibilityIdentifier, "delete-project")
        let shareLabel = try XCTUnwrap(descendants(of: UILabel.self, in: share).first { $0.text == "分享" })
        let removeLabel = try XCTUnwrap(descendants(of: UILabel.self, in: remove).first { $0.text == "删除" })
        XCTAssertEqual(shareLabel.font, UIFont.boldSystemFont(ofSize: 16))
        XCTAssertEqual(removeLabel.textColor, .systemRed, "危险操作的行文字应为红色")
        XCTAssertEqual(remove.frame.minY, share.frame.maxY, accuracy: 1, "行按添加顺序连续排列")
        let iconBox = try XCTUnwrap(descendants(of: UIView.self, in: share).first {
            $0.accessibilityIdentifier == "drawer-row-icon"
        })
        XCTAssertFalse(iconBox.isHidden)
        XCTAssertEqual(descendants(of: UIImageView.self, in: iconBox).first?.image, image)

        sheet.addButton(text: "归档", style: .highlight)
        host.layoutIfNeeded()
        XCTAssertEqual(sheet.tableView.numberOfRows(inSection: 0), 3)
        let titles = try (0..<3).map { index in
            try XCTUnwrap(descendants(of: UILabel.self, in: row(index, in: sheet)).first?.text)
        }
        XCTAssertEqual(titles, ["分享", "删除", "归档"], "显示期间追加行仍保持顺序，且没有多余取消行")
        XCTAssertEqual(try row(2, in: sheet).accessibilityIdentifier, "drawer-row-0-2")
        XCTAssertEqual(try row(1, in: sheet).accessibilityIdentifier, "delete-project")
        let archive = try row(2, in: sheet)
        let archiveLabel = try XCTUnwrap(descendants(of: UILabel.self, in: archive).first { $0.text == "归档" })
        XCTAssertEqual(archiveLabel.textColor, .systemPurple, "强调行使用 sheetConfig.highlightColor")
    }

    @MainActor
    func testSheetCanStartEmptyThenAddItsFirstRow() throws {
        let sheet = BoneDrawerSheetView(title: "项目操作")
        sheet.loadViewIfNeeded()
        XCTAssertEqual(sheet.tableView.numberOfSections, 0, "未添加业务行时不生成取消分区")
        sheet.addButton(text: "分享")
        let (window, _, _) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(sheet.tableView.numberOfSections, 1)
        XCTAssertEqual(sheet.tableView.numberOfRows(inSection: 0), 1)
        XCTAssertEqual(try row(0, in: sheet).accessibilityLabel, "分享")
    }

    /// 保留弹窗的行立即回调；默认行必须等关闭完成后才回调。
    @MainActor
    func testAddedRowsKeepDismissAndCallbackSemantics() async throws {
        let sheet = BoneDrawerSheetView(title: "项目操作")
        var refreshCount = 0
        sheet.addButton(text: "刷新状态", dismissesPopover: false) { [weak sheet] in
            XCTAssertEqual(sheet?.presentationState, .presented)
            refreshCount += 1
        }
        let (window, _, host) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }

        sheet.tableView.layoutIfNeeded()
        sheet.tableView(sheet.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(refreshCount, 1, "保留弹窗的行应同步执行回调")
        XCTAssertEqual(sheet.presentationState, .presented)
        XCTAssertNotNil(sheet.presentationHost)

        let callback = expectation(description: "default row calls back after dismissal")
        var callbackCount = 0
        sheet.addButton(text: "删除") { [weak sheet] in
            XCTAssertEqual(sheet?.presentationState, .hidden, "默认先关闭再执行业务回调")
            XCTAssertNil(sheet?.presentationHost)
            callbackCount += 1
            callback.fulfill()
        }
        host.layoutIfNeeded()
        XCTAssertEqual(sheet.tableView.numberOfRows(inSection: 0), 2)
        sheet.tableView.layoutIfNeeded()
        sheet.tableView(sheet.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
        await fulfillment(of: [callback], timeout: 3)
        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(sheet.presentationState, .hidden)
    }
}
