import XCTest
@testable import BonePopoverKit

final class PopoverContentStyleTests: XCTestCase {
    @MainActor
    private func present(_ popover: BonePopoverView, width: CGFloat = 390) throws
        -> (UIWindow, UIViewController, PopoverHostView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 1200))
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.view.frame = window.bounds
        XCTAssertTrue(popover.show(from: presenter, animated: false))
        presenter.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .large), forChild: popover)
        let host = try XCTUnwrap(popover.presentationHost)
        host.layoutIfNeeded()
        return (window, presenter, host)
    }

    @MainActor
    private func frame(_ view: UIView, in popover: BonePopoverView) -> CGRect {
        view.convert(view.bounds, to: popover.baseView)
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

    @MainActor
    private func headerFrame(in sheet: BoneDrawerSheetView) throws -> CGRect {
        let header = try XCTUnwrap(sheet.tableView.superview?.subviews.first {
            sheet.titleLabel.isDescendant(of: $0)
        })
        return frame(header, in: sheet)
    }

    @MainActor
    private func customStyle() -> PopoverContentStyle {
        var style = PopoverContentStyle()
        style.titleFont = .systemFont(ofSize: 22, weight: .semibold)
        style.messageFont = .monospacedSystemFont(ofSize: 15, weight: .regular)
        style.buttonFont = .systemFont(ofSize: 19, weight: .medium)
        style.inputFont = .monospacedSystemFont(ofSize: 16, weight: .medium)
        style.titleColor = .systemPurple
        style.messageColor = .systemOrange
        style.titleAlignment = .right
        style.messageAlignment = .center
        style.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 28, bottom: 30, trailing: 36)
        style.titleToContentSpacing = 9
        style.contentToButtonsSpacing = 23
        style.buttonSpacing = 18
        style.buttonContentInsets = NSDirectionalEdgeInsets(top: 16, leading: 22, bottom: 16, trailing: 22)
        style.adjustsFontForContentSizeCategory = false
        style.buttonLayout = .vertical
        return style
    }

    @MainActor
    func testDefaultAlertAndInputTitlesAre18PointBold() throws {
        let alert = BoneAlertView(title: "确认", message: "说明") {}
        let input = BoneAlertView(title: "输入", placeholder: "名称") { _ in }
        let presets: [(BonePopoverView, UILabel, UILabel, UIButton, NSTextAlignment)] = [
            (alert, alert.titleLabel, alert.messageLabel, alert.confirmButton, .left),
            (input, input.titleLabel, input.messageLabel, input.confirmButton, .left)
        ]
        for (popover, title, message, button, alignment) in presets {
            let (window, _, _) = try present(popover)
            defer { popover.dismissPopover(animated: false); window.isHidden = true }
            XCTAssertEqual(title.font.pointSize, 18, accuracy: 0.01)
            XCTAssertEqual(title.font.fontName, UIFont.boldSystemFont(ofSize: 18).fontName)
            XCTAssertTrue(title.font.fontDescriptor.symbolicTraits.contains(.traitBold))
            XCTAssertEqual(message.font.pointSize, 17, accuracy: 0.01)
            XCTAssertEqual(button.titleLabel?.font.pointSize ?? 0, 17, accuracy: 0.01)
            XCTAssertEqual(frame(title, in: popover).minY, 24, accuracy: 1)
            XCTAssertEqual(title.textAlignment, alignment)
            XCTAssertTrue(title.adjustsFontForContentSizeCategory)
        }
        XCTAssertEqual(input.textField.font?.pointSize ?? 0, 17, accuracy: 0.01)
    }

    @MainActor
    func testDrawerDefaultsUseHeaderTypographyAndTableRowMetrics() throws {
        let sheet = BoneDrawerSheetView(title: "操作", message: "说明")
        sheet.addButton(text: "分享")
        let (window, _, host) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }
        let expectedTitleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        XCTAssertEqual(sheet.titleLabel.font.pointSize, expectedTitleFont.pointSize, accuracy: 0.01)
        XCTAssertEqual(sheet.titleLabel.font.fontName, expectedTitleFont.fontName)
        XCTAssertEqual(sheet.titleLabel.font.fontDescriptor.symbolicTraits,
                       expectedTitleFont.fontDescriptor.symbolicTraits)
        XCTAssertEqual(sheet.titleLabel.textAlignment, .center)
        XCTAssertTrue(sheet.titleLabel.adjustsFontForContentSizeCategory)
        XCTAssertEqual(sheet.messageLabel.font.pointSize, 14, accuracy: 0.01)
        let first = try row(0, in: sheet)
        let label = try XCTUnwrap(descendants(of: UILabel.self, in: first).first { $0.text == "分享" })
        XCTAssertEqual(label.font, UIFont.boldSystemFont(ofSize: 16))
        XCTAssertEqual(first.bounds.height, 55, accuracy: 1)

        let insets = sheet.configuration.contentStyle.contentInsets
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.leading, 0)
        XCTAssertEqual(insets.bottom, 20)
        XCTAssertEqual(insets.trailing, 0)
        let message = frame(sheet.messageLabel, in: sheet)
        let table = frame(sheet.tableView, in: sheet)
        XCTAssertEqual(message.minX, 16, accuracy: 1)
        XCTAssertEqual(sheet.baseView.bounds.width - message.maxX, 16, accuracy: 1)
        XCTAssertEqual(message.minY - (try headerFrame(in: sheet)).maxY, 14, accuracy: 1)
        XCTAssertEqual(table.minY - message.maxY, 16, accuracy: 1)
        XCTAssertEqual(table.minX, 0, accuracy: 1)
        XCTAssertEqual(table.maxX, sheet.baseView.bounds.width, accuracy: 1)
        XCTAssertEqual(sheet.baseView.bounds.height - table.maxY, 20, accuracy: 1)
        XCTAssertTrue(sheet.configuration.appearance.showsGrabber)
        XCTAssertFalse(host.surface.grabber.isHidden)
        XCTAssertEqual(host.surface.contentContainer.frame.minY, 20, accuracy: 1,
                       "抓手区域由 Host 提供，不重复计入内容边距")
    }

    @MainActor
    func testCustomStyleBeforeLoadingControlsTypographyAndMeasuredAlertSpacing() throws {
        let alert = BoneAlertView(title: "自定义标题", message: "自定义正文") {}
        let style = customStyle()
        alert.configuration.contentStyle = style
        XCTAssertFalse(alert.isViewLoaded)
        let (window, _, _) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertEqual(alert.titleLabel.font, style.titleFont)
        XCTAssertEqual(alert.messageLabel.font, style.messageFont)
        XCTAssertEqual(alert.confirmButton.titleLabel?.font, style.buttonFont)
        XCTAssertEqual(alert.titleLabel.textColor, style.titleColor)
        XCTAssertEqual(alert.messageLabel.textColor, style.messageColor)
        XCTAssertEqual(alert.titleLabel.textAlignment, .right)
        XCTAssertEqual(alert.messageLabel.textAlignment, .center)
        XCTAssertFalse(alert.titleLabel.adjustsFontForContentSizeCategory)
        let title = frame(alert.titleLabel, in: alert)
        let message = frame(alert.messageLabel, in: alert)
        let confirm = frame(alert.confirmButton, in: alert)
        let cancel = frame(alert.cancelButton, in: alert)
        XCTAssertEqual(title.minY, 20, accuracy: 1)
        XCTAssertEqual(title.minX, 28, accuracy: 1)
        XCTAssertEqual(alert.baseView.bounds.width - title.maxX, 36, accuracy: 1)
        XCTAssertEqual(message.minY - title.maxY, 9, accuracy: 1)
        XCTAssertEqual(confirm.minY - message.maxY, 23, accuracy: 1)
        XCTAssertEqual(cancel.minY - confirm.maxY, 18, accuracy: 1)
        XCTAssertEqual(alert.baseView.bounds.height - cancel.maxY, 30, accuracy: 1)
        XCTAssertEqual(alert.confirmButton.configuration?.contentInsets.leading, 22)
        XCTAssertEqual(alert.confirmButton.configuration?.contentInsets.top, 16)
        XCTAssertGreaterThanOrEqual(confirm.height, style.buttonFont.lineHeight + 32 - 1)
    }

    @MainActor
    func testOperationListUsesMessageStyleAndIndependentTableRowMetrics() throws {
        for hasMessage in [false, true] {
            let image = try XCTUnwrap(UIImage(systemName: "trash")).withRenderingMode(.alwaysOriginal)
            let sheet = BoneDrawerSheetView(title: "项目操作", message: hasMessage ? "操作说明" : nil)
            sheet.addButton(text: "删除", icon: image, style: .destructive)
            sheet.addButton(text: "保留")
            var style = customStyle()
            style.buttonLayout = .horizontal
            sheet.configuration.contentStyle = style
            let (window, _, host) = try present(sheet)
            defer { sheet.dismissPopover(animated: false); window.isHidden = true }
            XCTAssertEqual(sheet.titleLabel.font, style.titleFont)
            XCTAssertEqual(sheet.titleLabel.textColor, style.titleColor)
            XCTAssertEqual(sheet.titleLabel.textAlignment, style.titleAlignment)
            XCTAssertEqual(sheet.messageLabel.font, style.messageFont)
            XCTAssertEqual(sheet.messageLabel.textColor, style.messageColor)
            XCTAssertEqual(sheet.messageLabel.textAlignment, style.messageAlignment)
            let table = frame(sheet.tableView, in: sheet)
            let contentBottom: CGFloat
            if hasMessage {
                let message = frame(sheet.messageLabel, in: sheet)
                XCTAssertEqual(message.minY - (try headerFrame(in: sheet)).maxY, 9, accuracy: 1)
                XCTAssertEqual(message.minX - table.minX, sheet.sheetConfig.headerInset, accuracy: 1)
                XCTAssertEqual(table.maxX - message.maxX, sheet.sheetConfig.headerInset, accuracy: 1)
                contentBottom = message.maxY
            } else {
                contentBottom = try headerFrame(in: sheet).maxY
            }
            XCTAssertEqual(table.minY - contentBottom, sheet.sheetConfig.listTopSpacing, accuracy: 1)
            XCTAssertEqual(table.minX, 28, accuracy: 1)
            XCTAssertEqual(sheet.baseView.bounds.width - table.maxX, 36, accuracy: 1)
            XCTAssertEqual(sheet.baseView.bounds.height - table.maxY, 30, accuracy: 1)
            let first = try row(0, in: sheet)
            let second = try row(1, in: sheet)
            XCTAssertEqual(first.bounds.height, sheet.sheetConfig.cellHeight, accuracy: 1)
            XCTAssertEqual(second.frame.minY, first.frame.maxY, accuracy: 1,
                           "表格行连续排列，不使用 Alert 的 buttonSpacing 或 buttonLayout")
            let label = try XCTUnwrap(descendants(of: UILabel.self, in: first).first { $0.text == "删除" })
            XCTAssertEqual(label.font, sheet.sheetConfig.fontSize)
            XCTAssertEqual(label.textColor, .systemRed)
            let icon = try XCTUnwrap(descendants(of: UIView.self, in: first).first {
                $0.accessibilityIdentifier == "drawer-row-icon"
            })
            XCTAssertEqual(descendants(of: UIImageView.self, in: icon).first?.image, image)

            sheet.configuration.contentStyle.buttonFont = .systemFont(ofSize: 50)
            sheet.configuration.contentStyle.buttonSpacing = 80
            sheet.configuration.contentStyle.buttonLayout = .vertical
            sheet.configuration.contentStyle.contentToButtonsSpacing = 90
            host.layoutIfNeeded()
            let unchanged = try row(0, in: sheet)
            let unchangedLabel = try XCTUnwrap(descendants(of: UILabel.self, in: unchanged).first {
                $0.text == "删除"
            })
            XCTAssertEqual(unchangedLabel.font, sheet.sheetConfig.fontSize)
            XCTAssertEqual(sheet.messageLabel.font, style.messageFont)
            XCTAssertEqual(unchanged.bounds.height, 55, accuracy: 1)
            XCTAssertEqual(frame(sheet.tableView, in: sheet).minY - contentBottom, 16, accuracy: 1)
            XCTAssertEqual(try row(1, in: sheet).frame.minY, unchanged.frame.maxY, accuracy: 1)

            sheet.sheetConfig.fontSize = .boldSystemFont(ofSize: 20)
            sheet.sheetConfig.cellHeight = 68
            sheet.sheetConfig.listTopSpacing = 24
            host.layoutIfNeeded()
            let updated = try row(0, in: sheet)
            let updatedLabel = try XCTUnwrap(descendants(of: UILabel.self, in: updated).first {
                $0.text == "删除"
            })
            XCTAssertEqual(updatedLabel.font, sheet.sheetConfig.fontSize)
            XCTAssertEqual(updated.bounds.height, 68, accuracy: 1)
            XCTAssertEqual(frame(sheet.tableView, in: sheet).minY - contentBottom, 24, accuracy: 1)

            sheet.sheetConfig.headerInset = 24
            host.layoutIfNeeded()
            if hasMessage {
                let message = frame(sheet.messageLabel, in: sheet)
                let table = frame(sheet.tableView, in: sheet)
                XCTAssertEqual(message.minX - table.minX, 24, accuracy: 1)
                XCTAssertEqual(table.maxX - message.maxX, 24, accuracy: 1)
            }
        }
    }

    @MainActor
    func testLiveStyleChangeRemeasuresAndPreservesInputFocusTextAndButtonContent() throws {
        let input = BoneAlertView(title: "编辑名称", placeholder: "名称") { _ in }
        input.text = "保留输入内容"
        let (window, _, host) = try present(input)
        defer { input.dismissPopover(animated: false); window.isHidden = true }
        XCTAssertTrue(input.textField.isFirstResponder)
        let originalHeight = host.panelFrame.height
        let image = UIImage(systemName: "checkmark")
        input.confirmButton.configuration?.title = "保存名称"
        input.confirmButton.configuration?.image = image
        input.textField.selectedTextRange = input.textField.textRange(
            from: input.textField.beginningOfDocument, to: input.textField.endOfDocument)
        input.configuration.contentStyle = customStyle()
        host.layoutIfNeeded()
        XCTAssertEqual(input.titleLabel.font, input.configuration.contentStyle.titleFont)
        XCTAssertEqual(input.textField.font, input.configuration.contentStyle.inputFont)
        XCTAssertEqual(input.text, "保留输入内容")
        XCTAssertTrue(input.textField.isFirstResponder)
        let selectedRange = try XCTUnwrap(input.textField.selectedTextRange)
        XCTAssertEqual(input.textField.offset(from: selectedRange.start, to: selectedRange.end), input.text.count)
        XCTAssertEqual(input.confirmButton.configuration?.title, "保存名称")
        XCTAssertEqual(input.confirmButton.configuration?.image, image)
        XCTAssertGreaterThan(host.panelFrame.height, originalHeight + 30)
        let title = frame(input.titleLabel, in: input)
        let field = frame(input.textField, in: input)
        let confirm = frame(input.confirmButton, in: input)
        XCTAssertEqual(field.minY - title.maxY, 9, accuracy: 1)
        XCTAssertEqual(confirm.minY - field.maxY, 23, accuracy: 1)
        input.configuration.contentStyle.titleFont = .boldSystemFont(ofSize: 26)
        XCTAssertEqual(input.titleLabel.font.pointSize, 26, accuracy: 0.01)
        XCTAssertEqual(input.text, "保留输入内容")
    }

    @MainActor
    func testDynamicTypeChangesScaleFromBaseFontsAndCanBeDisabled() throws {
        let alert = BoneAlertView(title: "动态标题", message: "正文随系统字号调整") {}
        let (window, presenter, host) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }
        let originalHeight = host.panelFrame.height
        let large = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        for _ in 0..<2 {
            presenter.setOverrideTraitCollection(large, forChild: alert)
            host.layoutIfNeeded()
            let style = alert.configuration.contentStyle
            let titleFont = UIFontMetrics(forTextStyle: .headline).scaledFont(for: style.titleFont, compatibleWith: large)
            let bodyFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: style.messageFont, compatibleWith: large)
            // UIKit propagates trait changes during subsequent layout work.
            // Wait for the rendered controls and panel to finish that update.
            let scaledLayout = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                alert.titleLabel.frame.height >= titleFont.lineHeight - 1 &&
                    alert.messageLabel.frame.height >= bodyFont.lineHeight - 1 &&
                    alert.confirmButton.frame.height >= bodyFont.lineHeight + 24 - 1
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [scaledLayout], timeout: 3), .completed)
            XCTAssertEqual(alert.titleLabel.font.pointSize, titleFont.pointSize, accuracy: 0.01)
            XCTAssertEqual(alert.messageLabel.font.pointSize, bodyFont.pointSize, accuracy: 0.01)
            XCTAssertEqual(alert.confirmButton.titleLabel?.font.pointSize ?? 0, bodyFont.pointSize, accuracy: 0.01)
            XCTAssertGreaterThan(host.panelFrame.height, originalHeight)
            XCTAssertGreaterThan(frame(alert.cancelButton, in: alert).minY, frame(alert.confirmButton, in: alert).maxY)
            presenter.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .large), forChild: alert)
            host.layoutIfNeeded()
            let restoredLayout = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(host.panelFrame.height - originalHeight) <= 1 && abs(alert.titleLabel.font.pointSize - 18) < 0.01
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [restoredLayout], timeout: 3), .completed)
            XCTAssertEqual(alert.titleLabel.font.pointSize, 18, accuracy: 0.01)
            XCTAssertEqual(host.panelFrame.height, originalHeight, accuracy: 1)
        }
        alert.configuration.contentStyle.adjustsFontForContentSizeCategory = false
        presenter.setOverrideTraitCollection(large, forChild: alert)
        host.layoutIfNeeded()
        let fixedFontLayout = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            alert.cancelButton.convert(alert.cancelButton.bounds, to: alert.baseView).minY >
                alert.confirmButton.convert(alert.confirmButton.bounds, to: alert.baseView).maxY
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [fixedFontLayout], timeout: 3), .completed)
        XCTAssertEqual(alert.titleLabel.font.pointSize, 18, accuracy: 0.01)
        XCTAssertEqual(alert.messageLabel.font.pointSize, 17, accuracy: 0.01)
        XCTAssertEqual(alert.confirmButton.titleLabel?.font.pointSize ?? 0, 17, accuracy: 0.01)
        XCTAssertFalse(alert.titleLabel.adjustsFontForContentSizeCategory)
        XCTAssertFalse(alert.confirmButton.titleLabel?.adjustsFontForContentSizeCategory ?? true)
    }

    @MainActor
    func testAutomaticButtonLayoutAccountsForStyledFontsPaddingAndSpacing() throws {
        let alert = BoneAlertView(title: "布局", message: "跟随样式自动调整") {}
        alert.configuration.contentStyle.adjustsFontForContentSizeCategory = false
        let (window, _, host) = try present(alert)
        defer { alert.dismissPopover(animated: false); window.isHidden = true }
        let originalStyle = alert.configuration.contentStyle
        func assertRow(_ expected: Bool, file: StaticString = #filePath, line: UInt = #line) {
            host.layoutIfNeeded()
            let confirm = frame(alert.confirmButton, in: alert)
            let cancel = frame(alert.cancelButton, in: alert)
            if expected { XCTAssertEqual(cancel.minY, confirm.minY, accuracy: 1, file: file, line: line) }
            else { XCTAssertGreaterThan(cancel.minY, confirm.maxY, file: file, line: line) }
        }
        assertRow(true)
        alert.configuration.contentStyle.buttonFont = .systemFont(ofSize: 60)
        assertRow(false)
        alert.configuration.contentStyle = originalStyle
        assertRow(true)
        alert.configuration.contentStyle.buttonContentInsets = NSDirectionalEdgeInsets(top: 12, leading: 70, bottom: 12, trailing: 70)
        assertRow(false)
        alert.configuration.contentStyle = originalStyle
        alert.configuration.contentStyle.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 100, bottom: 24, trailing: 100)
        assertRow(false)
        alert.configuration.contentStyle = originalStyle
        alert.configuration.contentStyle.buttonSpacing = 220
        assertRow(false)
        alert.configuration.contentStyle = originalStyle
        assertRow(true)
    }

    @MainActor
    func testConveniencePropertiesShareStyleAndFullConfigurationReplacesIt() {
        let alert = BoneAlertView(title: "标题", message: "正文") {}
        alert.loadViewIfNeeded()
        alert.titleAlignment = .right
        alert.buttonLayout = .vertical
        XCTAssertEqual(alert.configuration.contentStyle.titleAlignment, .right)
        XCTAssertEqual(alert.configuration.contentStyle.buttonLayout, .vertical)
        alert.configuration.contentStyle.titleAlignment = .center
        alert.configuration.contentStyle.buttonLayout = .horizontal
        XCTAssertEqual(alert.titleAlignment, .center)
        XCTAssertEqual(alert.titleLabel.textAlignment, .center)
        XCTAssertEqual(alert.buttonLayout, .horizontal)
        alert.configuration = .centerDialog
        XCTAssertEqual(alert.titleAlignment, .left)
        XCTAssertEqual(alert.titleLabel.textAlignment, .left)
        XCTAssertEqual(alert.buttonLayout, .automatic)
        let sheet = BoneDrawerSheetView(title: "列表")
        sheet.loadViewIfNeeded()
        sheet.titleAlignment = .right
        XCTAssertEqual(sheet.configuration.contentStyle.titleAlignment, .right)
        sheet.configuration.contentStyle.titleFont = .boldSystemFont(ofSize: 25)
        XCTAssertEqual(sheet.titleLabel.font.pointSize, 25, accuracy: 0.01)
        sheet.configuration = .bottomSheet
        XCTAssertEqual(sheet.titleAlignment, .center)
        XCTAssertEqual(sheet.titleLabel.font.pointSize, 18, accuracy: 0.01)
    }
}
