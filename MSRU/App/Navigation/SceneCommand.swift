//
//  SceneCommand.swift
//  MSRU
//


// MARK: - Scene Command

/*
 SceneCommand 描述：

 “调用者希望这个 Scene 做什么”

 Command 是瞬时 Intent，
 所以不进入 Restoration，也不 Codable。

 Route 可以持久化；
 Command 不需要持久化。
 */

nonisolated enum SceneCommand:
    Equatable,
    Sendable {

    case navigate(
        SceneRoute
    )
}
