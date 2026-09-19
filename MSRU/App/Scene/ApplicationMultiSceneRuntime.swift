//
//  ApplicationMultiSceneRuntime.swift
//  MSRU
//


// MARK: - Application Multi Scene Runtime

/*
 ApplicationMultiSceneRuntime 描述：

 “这个 Application Host
  具备管理多个 Scene 的能力”


 它是 capability contract。

 它不知道：

 - macOS
 - iOS
 - AppKit
 - UIKit
 - SwiftUI
 - NSWindow
 - UIWindow
 - Feature
 - Domain / Business


 Application Command Runtime
 只需要以下能力：

 1. route semantic request
 2. create Scene
 3. activate existing Scene


 当前 live implementation：

     MacSceneCoordinator


 Future implementation 可以是：

 - another Apple platform scene coordinator
 - test double
 - preview host
 - extracted framework consumer
 */

@MainActor
protocol ApplicationMultiSceneRuntime:
    AnyObject {

    // MARK: - Route

    /*
     将 semantic route
     发送到适当 Scene。

     返回最终处理该 route 的 SceneID。

     nil 表示 routing 无法完成。
     */

    @discardableResult
    func route(
        _ request:
            SceneRoutingRequest
    ) -> SceneID?


    // MARK: - Create

    /*
     创建新的 Scene。

     route == nil
         使用 runtime 默认初始状态。

     route != nil
         创建后立即应用 route。
     */

    @discardableResult
    func openNewScene(
        route:
            SceneRoute?
    ) -> SceneID


    // MARK: - Activate

    /*
     激活指定 Scene。

     false 表示 Scene 不存在。
     */

    @discardableResult
    func activateScene(
        _ sceneID:
            SceneID
    ) -> Bool
}
