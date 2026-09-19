//
//  ApplicationLifecycleTransitionResult.swift
//  MSRU
//


// MARK: - Lifecycle Transition Result

/*
 Lifecycle transition 不返回 Bool。

 Bool 无法表达：

 - 已成功 transition
 - 本来已经处于目标状态
 - 为什么无法 transition
 - activation flush 了哪些 commands
 */

nonisolated enum ApplicationLifecycleTransitionResult:
    Equatable,
    Sendable {

    // MARK: Transitioned

    case transitioned(
        to:
            ApplicationLifecyclePhase,
        commandResults:
            [ApplicationCommandResult]
    )


    // MARK: Unchanged

    /*
     操作是幂等的，
     当前 state 已经无需变化。
     */

    case unchanged(
        ApplicationLifecyclePhase
    )


    // MARK: Blocked

    case blocked(
        ApplicationLifecycleTransitionBlock
    )
}


// MARK: - Block

nonisolated enum ApplicationLifecycleTransitionBlock:
    Equatable,
    Sendable {

    /*
     markReady() 在 beginBootstrap()
     之前被调用。
     */

    case bootstrapNotStarted


    /*
     command runtime 当前还没有
     execution capability。

     例如 SingleScene runtime
     尚未 attach Scene。
     */

    case commandRuntimeUnavailable


    /*
     terminated 是 final state。
     */

    case terminated
}
