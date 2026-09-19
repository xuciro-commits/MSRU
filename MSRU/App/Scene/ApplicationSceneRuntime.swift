import AppFoundation

//
//  ApplicationSceneRuntime.swift
//  MSRU
//


// MARK: - Application Scene Runtime

/*
 ApplicationSceneRuntime 是 Application Command Runtime
 所能看到的最小 Scene capability。

 它故意不知道：

 - SwiftUI
 - AppKit
 - UIKit
 - Window
 - Feature
 - Navigation implementation
 - 具体业务


 Application 层只需要知道：

 1. Scene 的 identity
 2. Scene 可以接收 SceneCommand


 SceneModel 是当前 live implementation。

 Future implementations 可以是：

 - test double
 - preview runtime
 - alternate scene host
 - extracted framework consumer
 */

@MainActor
protocol ApplicationSceneRuntime:
    AnyObject {

    var id:
        SceneID { get }


    func send(
        _ command:
            SceneCommand
    )
}


// MARK: - SceneModel Conformance

extension SceneModel:
    ApplicationSceneRuntime {}
