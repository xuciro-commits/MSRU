//
//  ApplicationCommandResult.swift
//  MSRU
//


// MARK: - Application Command Result

/*
 ApplicationCommandResult 描述：

 “这条 ApplicationCommand
  在同步 dispatch 边界发生了什么”


 它不是业务结果。

 它只表达 application-command runtime 状态：

 - 已处理
 - 已落到某个 Scene
 - 已接受但延迟执行
 - 被拒绝
 */

nonisolated enum ApplicationCommandResult:
    Equatable,
    Sendable {

    // MARK: Handled

    case handled


    // MARK: Scene

    case scene(
        SceneID
    )


    // MARK: Deferred

    /*
     Command 已被 runtime 接受，
     但 execution boundary 尚未 ready。

     Command 会在 runtime ready 后执行。
     */

    case deferred


    // MARK: Rejected

    case rejected(
        ApplicationCommandRejection
    )
}


// MARK: - Rejection

nonisolated enum ApplicationCommandRejection:
    Equatable,
    Sendable {

    // MARK: Scene Not Found

    case sceneNotFound(
        SceneID
    )


    // MARK: Runtime Unavailable

    /*
     Command 已经进入 downstream handler，
     但对应 runtime 当前不存在。

     正常使用 ApplicationCommandGate 时，
     这个状态应该非常少见。

     它主要作为 defensive structured failure。
     */

    case runtimeUnavailable


    // MARK: Unsupported

    /*
     当前 hosting capability
     不支持这个 command。

     例如 SingleScene Runtime
     不具备 create-new-scene capability。
     */

    case unsupported
}


// MARK: - Projection

extension ApplicationCommandResult {

    // MARK: Executed

    var isHandled:
        Bool {

        switch self {

        case .handled,
             .scene:

            true


        case .deferred,
             .rejected:

            false
        }
    }


    // MARK: Accepted

    var isAccepted:
        Bool {

        switch self {

        case .handled,
             .scene,
             .deferred:

            true


        case .rejected:

            false
        }
    }


    // MARK: Deferred

    var isDeferred:
        Bool {

        self
        ==
        .deferred
    }


    // MARK: Scene

    var sceneID:
        SceneID? {

        switch self {

        case .scene(
            let sceneID
        ):

            sceneID


        case .handled,
             .deferred,
             .rejected:

            nil
        }
    }


    // MARK: Rejection

    var rejection:
        ApplicationCommandRejection? {

        switch self {

        case .rejected(
            let rejection
        ):

            rejection


        case .handled,
             .scene,
             .deferred:

            nil
        }
    }
}
