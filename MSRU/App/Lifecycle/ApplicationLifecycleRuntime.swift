//
//  ApplicationLifecycleRuntime.swift
//  MSRU
//


// MARK: - Application Lifecycle Runtime

/*
 ApplicationLifecycleRuntime
 是 platform-neutral lifecycle state machine。


 它负责：

 - lifecycle ordering
 - lifecycle idempotency
 - command runtime activation
 - command runtime suspension


 它不负责：

 - 创建 Window
 - restore Scene
 - 创建 Scene
 - load database
 - networking
 - business startup


 Platform Host 负责真正 bootstrap。

 Lifecycle Runtime 只负责宣布：

 “bootstrap 开始”
 “runtime 已 ready”


 Pipeline:

 Platform
    │
    │ beginBootstrap()
    ▼
 bootstrapping
    │
    │ platform constructs runtime
    │
    │ markReady()
    ▼
 ApplicationLifecycleRuntime
    │
    ▼
 ApplicationCommandRuntimeLifecycle.activate()
    │
    ▼
 ready
 */

@MainActor
final class ApplicationLifecycleRuntime {

    // MARK: - Phase

    private(set) var phase:
        ApplicationLifecyclePhase =
            .initialized


    // MARK: - Command Runtime

    private let commandRuntime:
        any ApplicationCommandRuntimeLifecycle


    // MARK: - Init

    init(
        commandRuntime:
            any ApplicationCommandRuntimeLifecycle
    ) {

        self.commandRuntime =
            commandRuntime
    }


    // MARK: - Bootstrap

    @discardableResult
    func beginBootstrap()
        -> ApplicationLifecycleTransitionResult {

        switch phase {

        case .initialized:

            phase =
                .bootstrapping


            return
                .transitioned(
                    to:
                        .bootstrapping,
                    commandResults:
                        []
                )


        case .bootstrapping,
             .ready,
             .suspended:

            return
                .unchanged(
                    phase
                )


        case .terminated:

            return
                .blocked(
                    .terminated
                )
        }
    }


    // MARK: - Ready

    /*
     Platform 必须在自己的 runtime
     真正完成 bootstrap 后调用。

     Lifecycle Runtime 不猜测
     platform readiness。
     */

    @discardableResult
    func markReady()
        -> ApplicationLifecycleTransitionResult {

        switch phase {

        case .initialized:

            return
                .blocked(
                    .bootstrapNotStarted
                )


        case .bootstrapping:

            guard
                commandRuntime
                    .canActivate
            else {

                return
                    .blocked(
                        .commandRuntimeUnavailable
                    )
            }


            let commandResults =
                commandRuntime
                    .activate()


            phase =
                .ready


            return
                .transitioned(
                    to:
                        .ready,
                    commandResults:
                        commandResults
                )


        case .ready:

            return
                .unchanged(
                    .ready
                )


        case .suspended:

            /*
             suspended -> ready
             应该显式使用 resume()。

             markReady() 不偷偷改变
             resume semantic。
             */

            return
                .unchanged(
                    .suspended
                )


        case .terminated:

            return
                .blocked(
                    .terminated
                )
        }
    }


    // MARK: - Suspend

    @discardableResult
    func suspend()
        -> ApplicationLifecycleTransitionResult {

        switch phase {

        case .ready:

            commandRuntime
                .suspend()


            phase =
                .suspended


            return
                .transitioned(
                    to:
                        .suspended,
                    commandResults:
                        []
                )


        case .suspended:

            return
                .unchanged(
                    .suspended
                )


        case .initialized,
             .bootstrapping:

            /*
             bootstrap 尚未形成 ready runtime。

             当前不制造额外 intermediate state。
             */

            return
                .unchanged(
                    phase
                )


        case .terminated:

            return
                .blocked(
                    .terminated
                )
        }
    }


    // MARK: - Resume

    @discardableResult
    func resume()
        -> ApplicationLifecycleTransitionResult {

        switch phase {

        case .suspended:

            guard
                commandRuntime
                    .canActivate
            else {

                return
                    .blocked(
                        .commandRuntimeUnavailable
                    )
            }


            let commandResults =
                commandRuntime
                    .activate()


            phase =
                .ready


            return
                .transitioned(
                    to:
                        .ready,
                    commandResults:
                        commandResults
                )


        case .ready:

            return
                .unchanged(
                    .ready
                )


        case .initialized:

            return
                .blocked(
                    .bootstrapNotStarted
                )


        case .bootstrapping:

            return
                .unchanged(
                    .bootstrapping
                )


        case .terminated:

            return
                .blocked(
                    .terminated
                )
        }
    }


    // MARK: - Terminate

    /*
     terminated 是 final state。

     command runtime 必须立即 suspend，
     之后不能通过 lifecycle 恢复。
     */

    @discardableResult
    func terminate()
        -> ApplicationLifecycleTransitionResult {

        guard
            phase
            !=
            .terminated
        else {

            return
                .unchanged(
                    .terminated
                )
        }


        commandRuntime
            .suspend()


        phase =
            .terminated


        return
            .transitioned(
                to:
                    .terminated,
                commandResults:
                    []
            )
    }
}
