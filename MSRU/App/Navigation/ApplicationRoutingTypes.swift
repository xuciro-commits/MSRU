//
//  ApplicationRoutingTypes.swift
//  MSRU
//

import AppFoundation


// MARK: - MSRU Routing Bindings

/*
 AppFoundation 提供通用 routing mechanics。

 MSRU 只负责提供自己的 concrete Route：

     SceneRoute

 Foundation 不知道 SceneRoute 内部包含：

 - listenNow
 - browse
 - library
 - addMusic
 - settings

 也不应该知道。


 这里是 Host Application
 与 AppFoundation 之间唯一的 specialization boundary。
 */


typealias SceneID =
    AppFoundation.SceneID


typealias SceneRoutingTarget =
    AppFoundation.SceneRoutingTarget


typealias SceneRoutingRequest =
    AppFoundation.SceneRoutingRequest<
        SceneRoute
    >


typealias SceneCommand =
    AppFoundation.SceneCommand<
        SceneRoute
    >


typealias ApplicationCommand =
    AppFoundation.ApplicationCommand<
        SceneRoute
    >
