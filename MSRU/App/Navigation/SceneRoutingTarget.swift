//
//  SceneRoutingTarget.swift
//  MSRU
//


// MARK: - Scene Routing Target

/*
 SceneRoutingTarget 描述：

 “这条 Route 应该发送到哪个 Scene”

 它不描述 Route 内容本身。
 */

nonisolated enum SceneRoutingTarget:
    Equatable,
    Sendable {

    /*
     优先使用当前 active Scene。

     如果没有 Scene，
     创建一个新的 Scene。
     */

    case activeOrNew


    /*
     明确创建新的 Scene。
     */

    case new


    /*
     明确发送到指定 Scene。

     如果 Scene 已不存在，
     routing 会失败，
     不偷偷创建 replacement。
     */

    case scene(
        SceneID
    )
}
