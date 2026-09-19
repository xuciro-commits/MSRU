//
//  MSRUFoundationTypeAliases.swift
//  MSRUTests
//

import AppFoundation

@testable import MSRU


// MARK: - Host Routing Types

/*
 MSRUTests 同时能够看到：

 AppFoundation.SceneCommand<Route>

 和：

 MSRU.SceneCommand
     = AppFoundation.SceneCommand<SceneRoute>


 测试绝大多数时候验证的是 MSRU Host Application，
 因此在测试模块建立明确的 Host specialization。

 这样：

 SceneCommand
 SceneRoutingRequest
 ApplicationCommand
 SceneID

 在 MSRUTests 中始终表示 MSRU 的具体类型。
 */

typealias SceneID =
    MSRU.SceneID


typealias SceneRoutingTarget =
    MSRU.SceneRoutingTarget


typealias SceneRoutingRequest =
    MSRU.SceneRoutingRequest


typealias SceneCommand =
    MSRU.SceneCommand


typealias ApplicationCommand =
    MSRU.ApplicationCommand
