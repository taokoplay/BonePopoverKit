import UIKit
import XCTest
@testable import BonePopoverKit

final class PopoverWindowSceneTests: XCTestCase {
    @MainActor
    func testLiveSceneDestructionDoesNotCloseTheOtherScenesPopover() async throws {
        guard UIApplication.shared.supportsMultipleScenes else {
            throw XCTSkip("当前运行环境不支持多个 Scene；其余窗口用例继续执行。")
        }
        let app = UIApplication.shared
        let firstScene = try XCTUnwrap(app.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive }))
        let existing = Set(app.connectedScenes.map { $0.session.persistentIdentifier })
        let activity = NSUserActivity(activityType: "dev.bone.window-demo")
        activity.userInfo = ["secondary": true]
        app.requestSceneSessionActivation(nil, userActivity: activity, options: nil) { error in
            XCTFail("第二 Scene 激活失败：\(error)")
        }
        let connected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.connectedScenes.contains { !existing.contains($0.session.persistentIdentifier) }
        }, object: nil)
        await fulfillment(of: [connected], timeout: 15)
        let secondScene = try XCTUnwrap(app.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { !existing.contains($0.session.persistentIdentifier) }))
        let sourceA = UIWindow(windowScene: firstScene)
        let sourceB = UIWindow(windowScene: secondScene)
        sourceA.rootViewController = UIViewController()
        sourceB.rootViewController = UIViewController()
        sourceA.isHidden = false
        sourceB.makeKeyAndVisible()
        let first = BonePopoverView(configuration: .centerDialog)
        let second = BonePopoverView(configuration: .centerDialog)
        defer {
            first.dismissPopover(animated: false)
            second.dismissPopover(animated: false)
            sourceA.isHidden = true
            sourceB.isHidden = true
            sourceA.windowScene = nil
            sourceB.windowScene = nil
            app.requestSceneSessionActivation(firstScene.session, userActivity: nil, options: nil)
        }
        XCTAssertTrue(first.show(over: sourceA, animated: false))
        XCTAssertTrue(second.show(over: sourceB, animated: false))
        XCTAssertTrue(first.view.window?.windowScene === firstScene)
        XCTAssertTrue(second.view.window?.windowScene === secondScene)
        XCTAssertEqual(PopoverWindowCoordinator.shared.sessions(in: firstScene).count, 1)
        XCTAssertEqual(PopoverWindowCoordinator.shared.sessions(in: secondScene).count, 1)
        var destructionError: Error?
        app.requestSceneSessionDestruction(secondScene.session, options: nil) { error in
            destructionError = error
        }
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            second.presentationState == .hidden || destructionError != nil
        }, object: nil)
        await fulfillment(of: [removed], timeout: 15)
        if let error = destructionError {
            let detail = error as NSError
            if detail.domain == "SBApplicationSupportService", detail.code == 1 {
                throw XCTSkip("已验证两个真实 Scene 的会话隔离；系统拒绝销毁该设备的 Scene：\(error)")
            }
            XCTFail("第二 Scene 关闭失败：\(error)")
            return
        }
        XCTAssertEqual(second.presentationState, .hidden)
        XCTAssertTrue(PopoverWindowCoordinator.shared.sessions(in: secondScene).isEmpty)
        XCTAssertEqual(first.presentationState, .presented)
        XCTAssertEqual(PopoverWindowCoordinator.shared.sessions(in: firstScene).count, 1)
    }
}
