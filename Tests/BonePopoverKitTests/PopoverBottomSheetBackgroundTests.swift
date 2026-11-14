import XCTest
@testable import BonePopoverKit

final class PopoverBottomSheetBackgroundTests: XCTestCase {
    @MainActor
    private func present(_ sheet: BoneDrawerSheetView) throws -> (UIWindow, PopoverHostView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 900))
        let presenter = UIViewController()
        presenter.additionalSafeAreaInsets.bottom = 34
        presenter.view.backgroundColor = .white
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.view.frame = window.bounds
        presenter.view.layoutIfNeeded()
        XCTAssertTrue(sheet.show(from: presenter, animated: false))
        let host = try XCTUnwrap(sheet.presentationHost)
        host.layoutIfNeeded()
        return (window, host)
    }

    /// 背景覆盖安全区，内容仍停在安全区上沿；三种抽屉在浅色/深色下都不能露底。
    @MainActor
    func testDrawerVariantsFillBottomSafeAreaWithTheirBackgroundColor() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for variant in 0..<3 {
                let sheet = BoneDrawerSheetView(title: "抽屉")
                sheet.configuration.interfaceStyle = style
                sheet.showsConfirmButton = true
                let rowCount = variant == 2 ? 14 : 3
                for index in 0..<rowCount {
                    sheet.addButton(text: "选项 \(index)",
                                    inSection: .singleSelect("选择", index == 0))
                }
                if variant == 1 {
                    sheet.addButton(text: "第一章", inSection: .drag("排序"))
                    sheet.addButton(text: "第二章", inSection: .drag("排序"))
                }
                if variant == 2 { sheet.sheetConfig.maximumListHeight = 240 }
                let (window, host) = try present(sheet)
                defer { sheet.dismissPopover(animated: false); window.isHidden = true }

                XCTAssertGreaterThan(host.safeAreaInsets.bottom, 0)
                let safeBottom = host.bounds.maxY - host.safeAreaInsets.bottom
                XCTAssertEqual(host.surface.frame.maxY, host.bounds.maxY, accuracy: 0.5,
                               "抽屉背景必须铺到底边：variant=\(variant), style=\(style.rawValue)")
                let content = host.surface.contentContainer
                XCTAssertEqual(content.convert(content.bounds, to: host).maxY, safeBottom, accuracy: 0.5,
                               "列表和按钮仍应避让底部安全区")
                XCTAssertEqual(sheet.tableView.isScrollEnabled, variant == 2)
                let image = UIGraphicsImageRenderer(bounds: host.bounds).image {
                    window.layer.render(in: $0.cgContext)
                }
                let expected = sheet.configuration.appearance.backgroundColor
                    .resolvedColor(with: host.traitCollection)
                // 在底部左、中、右各取一点，避开系统 Home 指示条。
                for x in [CGFloat(8), host.bounds.midX, host.bounds.maxX - 8] {
                    let actual = try pixel(in: image, at: CGPoint(x: x, y: host.bounds.maxY - 3))
                    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                    XCTAssertTrue(expected.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
                    XCTAssertEqual(actual[0], red * 255, accuracy: 2, "底部不能透出宿主白底")
                    XCTAssertEqual(actual[1], green * 255, accuracy: 2)
                    XCTAssertEqual(actual[2], blue * 255, accuracy: 2)
                }
            }
        }
    }

    /// 有意悬浮的面板保留留白，键盘/横向保留区上方的面板也不能向下越过避让区。
    @MainActor
    func testFloatingAndExcludedBottomEdgesKeepTheirClearance() throws {
        let sheet = BoneDrawerSheetView(title: "抽屉")
        sheet.addButton(text: "选项")
        sheet.configuration.layout.margins.bottom = 12
        let (window, host) = try present(sheet)
        defer { sheet.dismissPopover(animated: false); window.isHidden = true }
        let safeBottom = host.bounds.maxY - host.safeAreaInsets.bottom
        XCTAssertEqual(host.surface.frame.maxY, safeBottom - 12, accuracy: 0.5)

        sheet.configuration.layout.margins.bottom = 0
        let exclusion = CGRect(x: 0, y: host.bounds.maxY - 220,
                               width: host.bounds.width, height: 220)
        sheet.reservedRegionProvider = { _ in [exclusion] }
        host.layoutIfNeeded()
        XCTAssertEqual(host.surface.frame.maxY, exclusion.minY, accuracy: 0.5,
                       "背景必须留在键盘或保留区上方")

        sheet.reservedRegionProvider = { _ in [] }
        host.layoutIfNeeded()
        XCTAssertEqual(host.surface.frame.maxY, host.bounds.maxY, accuracy: 0.5,
                       "移除避让区后恢复背景铺底")
    }

    private func pixel(in image: UIImage, at point: CGPoint) throws -> [CGFloat] {
        let imageRef = try XCTUnwrap(image.cgImage)
        let crop = try XCTUnwrap(imageRef.cropping(to: CGRect(x: point.x * image.scale,
                                                            y: point.y * image.scale,
                                                            width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1,
                                             bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return bytes.map(CGFloat.init)
    }
}
