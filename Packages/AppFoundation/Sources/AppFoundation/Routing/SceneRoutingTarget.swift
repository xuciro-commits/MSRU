//
//  SceneRoutingTarget.swift
//  AppFoundation
//


// MARK: - Scene Routing Target

/*
 SceneRoutingTarget 回答：

 “Route 应该在哪个 Scene 中打开？”

 它完全不关心：

 “Route 本身是什么？”
 */

public enum SceneRoutingTarget:
    Equatable,
    Hashable,
    Sendable {

    /*
     优先使用 active Scene。

     如果没有可用 Scene，
     runtime 可以创建新 Scene。
     */
    case activeOrNew


    /*
     明确要求创建新的 Scene。
     */
    case new


    /*
     明确发送到已有 Scene。
     */
    case scene(
        SceneID
    )
}
