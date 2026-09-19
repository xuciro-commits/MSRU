import AppFoundation

//
//  SingleSceneApplicationCommandRuntime.swift
//  MSRU
//


// MARK: - Single Scene Application Command Runtime

/*
 SingleSceneApplicationCommandRuntime
 是 single-scene host 的 command composition object。


 Pipeline:

 ApplicationCommand
        │
        ▼
 ApplicationCommandGate
        │
        ▼
 SingleSceneApplicationCommandHandler
        │
        ▼
 ApplicationSceneRuntime


 Wiring lifecycle：

 init
   │
   └── no Scene / suspended

 attach(scene)
   │
   └── Scene capability available
       但 command runtime 仍 suspended

 lifecycle.markReady()
   │
   ▼
 activate()
   │
   └── FIFO flush


 重要：

 attach != activate

 Runtime wiring 与 lifecycle readiness
 是两个不同概念。
 */

@MainActor
final class SingleSceneApplicationCommandRuntime:
    ApplicationCommandRuntimeLifecycle {

    // MARK: - Components

    private let handler:
        SingleSceneApplicationCommandHandler


    private let gate:
        ApplicationCommandGate


    // MARK: - Init

    init() {

        let handler =
            SingleSceneApplicationCommandHandler()


        let gate =
            ApplicationCommandGate(
                downstream:
                    handler
            )


        self.handler =
            handler


        self.gate =
            gate


    }


    // MARK: - Lifecycle Capability

    var canActivate:
        Bool {

        handler
            .isAttached
    }


    var isActive:
        Bool {

        gate.isActive
        &&
        handler.isAttached
    }


    var sceneID:
        SceneID? {

        handler
            .sceneID
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


    // MARK: - Attach

    /*
     只建立 runtime wiring。

     不改变 Command Gate lifecycle。
     */

    func attach(
        _ scene:
            any ApplicationSceneRuntime
    ) {

        handler
            .attach(
                scene
            )
    }


    // MARK: - Activate

    @discardableResult
    func activate()
        -> [ApplicationCommandResult] {

        guard
            canActivate
        else {

            return []
        }


        return
            gate
                .activate()
    }


    // MARK: - Suspend

    func suspend() {

        gate
            .suspend()
    }


    // MARK: - Detach

    /*
     Scene detach 后：

     - gate suspended
     - old Scene released
     - future commands deferred
     */

    func detach() {

        suspend()


        handler
            .detach()
    }
}
