import AppFoundation

//
//  MultiSceneApplicationCommandRuntime.swift
//  MSRU
//


// MARK: - Multi Scene Application Command Runtime

/*
 MultiSceneApplicationCommandRuntime
 是 multi-scene host 的 command composition object。


 Pipeline:

 ApplicationCommand
        │
        ▼
 ApplicationCommandGate
        │
        ▼
 MultiSceneApplicationCommandHandler
        │
        ▼
 ApplicationMultiSceneRuntime


 Lifecycle readiness
 由 ApplicationLifecycleRuntime 控制。
 */

@MainActor
final class MultiSceneApplicationCommandRuntime:
    ApplicationCommandRuntimeLifecycle {

    // MARK: - Gate

    private let gate:
        ApplicationCommandGate


    // MARK: - Command Center

    // MARK: - Init

    init(
        runtime:
            any ApplicationMultiSceneRuntime,
        startsActive:
            Bool = false
    ) {

        let handler =
            MultiSceneApplicationCommandHandler(
                runtime:
                    runtime
            )


        let gate =
            ApplicationCommandGate(
                downstream:
                    handler,
                startsActive:
                    startsActive
            )


        self.gate =
            gate


    }


    // MARK: - Lifecycle Capability

    /*
     Multi-Scene runtime 本身已经拥有 host capability。

     Platform bootstrap completion
     由调用 lifecycle.markReady()
     的时机表达。
     */

    var canActivate:
        Bool {

        true
    }


    var isActive:
        Bool {

        gate
            .isActive
    }


    var pendingCommandCount:
        Int {

        gate
            .pendingCount
    }


    // MARK: - Send

    @discardableResult
    func send(
        _ command:
            ApplicationCommand
    ) -> ApplicationCommandResult {

        gate.handle(command)
    }


    @discardableResult
    func send(
        _ commands:
            [ApplicationCommand]
    ) -> [ApplicationCommandResult] {

        commands.map { gate.handle($0) }
    }


    // MARK: - Activate

    @discardableResult
    func activate()
        -> [ApplicationCommandResult] {

        gate
            .activate()
    }


    // MARK: - Suspend

    func suspend() {

        gate
            .suspend()
    }
}
