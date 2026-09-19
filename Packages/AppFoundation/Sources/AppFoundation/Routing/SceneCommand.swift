//
//  SceneCommand.swift
//  AppFoundation
//


// MARK: - Scene Command

/*
 SceneCommand 描述：

 “一个已经确定的 Scene 应该做什么？”


 它不包含：

 - Scene selection policy
 - Scene creation policy
 - Window creation
 - External URL parsing


 这些属于 Application 层。
 */

public enum SceneCommand<Route>:
    Equatable,
    Hashable,
    Sendable
where
    Route:
        Hashable & Sendable {

    case navigate(
        Route
    )
}
