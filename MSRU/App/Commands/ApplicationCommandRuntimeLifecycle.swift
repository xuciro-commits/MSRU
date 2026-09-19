//
//  ApplicationCommandRuntimeLifecycle.swift
//  MSRU
//


// MARK: - Application Command Runtime Lifecycle

/*
 ApplicationCommandRuntimeLifecycle 描述：

 “Application lifecycle
  可以如何控制 command runtime”


 它不描述：

 - platform lifecycle API
 - Scene implementation
 - Window
 - Feature
 - Domain
 - Business


 Lifecycle 只需要知道：

 1. runtime 当前能否进入 active
 2. runtime 当前是否 active
 3. activate
 4. suspend


 Single-Scene 与 Multi-Scene Runtime
 都实现这个 capability。
 */

@MainActor
protocol ApplicationCommandRuntimeLifecycle:
    AnyObject {

    // MARK: - Capability

    /*
     当前 runtime 是否已经具备
     command execution 所需要的 host。

     Single Scene：

         Scene 已 attach

     Multi Scene：

         composition root 决定
         何时调用 lifecycle.markReady()
    */

    var canActivate:
        Bool { get }


    // MARK: - State

    var isActive:
        Bool { get }


    // MARK: - Activate

    /*
     激活 runtime。

     返回 activation 时
     FIFO flush 的 deferred command results。
     */

    @discardableResult
    func activate()
        -> [ApplicationCommandResult]


    // MARK: - Suspend

    /*
     suspend 后的新 commands
     重新进入 Command Gate buffer。
     */

    func suspend()
}
