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
        let host = try XCTUnwrap(presenter.view.subviews.compactMap { $0 as? PopoverHostView }.first)
        host.layoutIfNeeded()
        return (window, presenter, host)
    }

    @MainActor
    private func frame(_ view: UIView, in popover: BonePopoverView) -> CGRect {
        view.convert(view.bounds, to: popover.baseView)
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
    func testDefaultTitleIs18PointBoldInAllPresets() throws {
        let alert = BoneAlertView(title: "确认", message: "说明") {}
        let input = BoneAlertView(title: "输入", placeholder: "名称") { _ in }
        let sheet = BoneActionSheetView(title: "操作", message: "说明", actions: [PopoverAction("分享")])
        let presets: [(BonePopoverView, UILabel, UILabel, UIButton)] = [
            (alert, alert.titleLabel, alert.messageLabel, alert.confirmButton),
            (input, input.titleLabel, input.messageLabel, input.confirmButton),
            (sheet, sheet.titleLabel, sheet.messageLabel, sheet.cancelButton)
        ]
        for (popover, title, message, button) in presets {
            let (window, _, _) = try present(popover)
            defer { popover.dismissPopover(animated: false); window.isHidden = true }
            XCTAssertEqual(title.font.pointSize, 18, accuracy: 0.01)
            XCTAssertEqual(title.font.fontName, UIFont.boldSystemFont(ofSize: 18).fontName)
            XCTAssertTrue(title.font.fontDescriptor.symbolicTraits.contains(.traitBold))
            XCTAssertEqual(message.font.pointSize, 17, accuracy: 0.01)
            XCTAssertEqual(button.titleLabel?.font.pointSize ?? 0, 17, accuracy: 0.01)
            XCTAssertEqual(frame(title, in: popover).minY, 24, accuracy: 1)
            XCTAssertEqual(title.textAlignment, .left)
            XCTAssertTrue(title.adjustsFontForContentSizeCategory)
        }
        XCTAssertEqual(input.textField.font?.pointSize ?? 0, 17, accuracy: 0.01)
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
    func testActionListUsesSharedStyleAndRetainsVerticalActionsAndImages() throws {
        for hasMessage in [false, true] {
            let image = UIImage(systemName: "trash")
            let sheet = BoneActionSheetView(title: "项目操作", message: hasMessage ? "操作说明" : nil, actions: [
                PopoverAction("删除", image: image, role: .destructive), PopoverAction("保留")
            ])
            var style = customStyle()
            style.buttonLayout = .horizontal
            sheet.configuration.contentStyle = style
            let (window, _, _) = try present(sheet)
            defer { sheet.dismissPopover(animated: false); window.isHidden = true }
            XCTAssertEqual(sheet.titleLabel.font, style.titleFont)
            XCTAssertEqual(sheet.messageLabel.font, style.messageFont)
            let title = frame(sheet.titleLabel, in: sheet)
            let first = frame(sheet.actionButtons[0], in: sheet)
            let second = frame(sheet.actionButtons[1], in: sheet)
            let cancel = frame(sheet.cancelButton, in: sheet)
            if hasMessage {
                let message = frame(sheet.messageLabel, in: sheet)
                XCTAssertEqual(message.minY - title.maxY, 9, accuracy: 1)
                XCTAssertEqual(first.minY - message.maxY, 23, accuracy: 1)
            } else {
                XCTAssertEqual(first.minY - title.maxY, 23, accuracy: 1)
            }
            XCTAssertEqual(first.minX, 28, accuracy: 1)
            XCTAssertEqual(sheet.baseView.bounds.width - first.maxX, 36, accuracy: 1)
            XCTAssertEqual(second.minY - first.maxY, 18, accuracy: 1)
            XCTAssertEqual(cancel.minY - second.maxY, 18, accuracy: 1)
            XCTAssertEqual(sheet.baseView.bounds.height - cancel.maxY, 30, accuracy: 1)
            XCTAssertEqual(sheet.actionButtons[0].configuration?.image, image)
            XCTAssertEqual(sheet.actionButtons[0].tintColor, .systemRed)
            XCTAssertEqual(sheet.actionButtons[0].titleLabel?.font, style.buttonFont)
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
        let sheet = BoneActionSheetView(title: "列表", actions: [])
        sheet.loadViewIfNeeded()
        sheet.titleAlignment = .center
        XCTAssertEqual(sheet.configuration.contentStyle.titleAlignment, .center)
        sheet.configuration.contentStyle.titleFont = .boldSystemFont(ofSize: 25)
        XCTAssertEqual(sheet.titleLabel.font.pointSize, 25, accuracy: 0.01)
        sheet.configuration = .bottomSheet
        XCTAssertEqual(sheet.titleAlignment, .left)
        XCTAssertEqual(sheet.titleLabel.font.pointSize, 18, accuracy: 0.01)
    }
}
