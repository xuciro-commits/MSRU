//
//  ApplicationCommandGateTests.swift
//  MSRUTests
//

import Testing

@testable import MSRU


@MainActor
struct ApplicationCommandGateTests {

    // MARK: - Deferred

    @Test
    func suspendedGateDefersCommand() {

        let downstream =
            GateRecordingHandler()


        let gate =
            ApplicationCommandGate(
                downstream:
                    downstream
            )


        let result =
            gate
                .handle(
                    .newScene
                )


        #expect(
            result
            ==
            .deferred
        )

        #expect(
            result.isAccepted
        )

        #expect(
            !result.isHandled
        )

        #expect(
            gate.pendingCount
            ==
            1
        )

        #expect(
            downstream.commands
                .isEmpty
        )
    }


    // MARK: - FIFO

    @Test
    func activationFlushesCommandsInFIFOOrder() {

        let downstream =
            GateRecordingHandler()


        let gate =
            ApplicationCommandGate(
                downstream:
                    downstream
            )


        let commands:
            [ApplicationCommand] = [

                .open(
                    .section(
                        .browse
                    )
                ),

                .open(
                    .section(
                        .library
                    )
                ),

                .newScene
            ]


        for command
        in commands {

            gate
                .handle(
                    command
                )
        }


        let results =
            gate
                .activate()


        #expect(
            downstream.commands
            ==
            commands
        )

        #expect(
            results.count
            ==
            commands.count
        )

        #expect(
            gate.pendingCount
            ==
            0
        )

        #expect(
            gate.isActive
        )
    }


    // MARK: - Active Passthrough

    @Test
    func activeGateImmediatelyForwardsCommand() {

        let sceneID =
            SceneID()


        let downstream =
            GateRecordingHandler(
                result:
                    .scene(
                        sceneID
                    )
            )


        let gate =
            ApplicationCommandGate(
                downstream:
                    downstream,
                startsActive:
                    true
            )


        let result =
            gate
                .handle(
                    .newScene
                )


        #expect(
            result
            ==
            .scene(
                sceneID
            )
        )

        #expect(
            gate.pendingCount
            ==
            0
        )

        #expect(
            downstream.commands
            ==
            [
                .newScene
            ]
        )
    }


    // MARK: - Idempotent Activation

    @Test
    func repeatedActivationDoesNotReplayCommands() {

        let downstream =
            GateRecordingHandler()


        let gate =
            ApplicationCommandGate(
                downstream:
                    downstream
            )


        gate
            .handle(
                .newScene
            )


        let firstResults =
            gate
                .activate()


        let secondResults =
            gate
                .activate()


        #expect(
            firstResults.count
            ==
            1
        )

        #expect(
            secondResults
                .isEmpty
        )

        #expect(
            downstream.commands.count
            ==
            1
        )
    }


    // MARK: - Resuspend

    @Test
    func suspendedActiveGateBuffersNewCommandsAgain() {

        let downstream =
            GateRecordingHandler()


        let gate =
            ApplicationCommandGate(
                downstream:
                    downstream,
                startsActive:
                    true
            )


        gate
            .handle(
                .newScene
            )


        gate
            .suspend()


        let deferred =
            gate
                .handle(
                    .open(
                        .section(
                            .settings
                        )
                    )
                )


        #expect(
            deferred
            ==
            .deferred
        )

        #expect(
            downstream.commands.count
            ==
            1
        )

        #expect(
            gate.pendingCount
            ==
            1
        )


        gate
            .activate()


        #expect(
            downstream.commands.count
            ==
            2
        )

        #expect(
            gate.pendingCount
            ==
            0
        )
    }
}


// MARK: - Recording Handler

@MainActor
private final class GateRecordingHandler:
    ApplicationCommandHandler {

    private(set) var commands:
        [ApplicationCommand] = []


    private let result:
        ApplicationCommandResult


    init(
        result:
            ApplicationCommandResult =
                .handled
    ) {

        self.result =
            result
    }


    func handle(
        _ command:
            ApplicationCommand
    ) -> ApplicationCommandResult {

        commands
            .append(
                command
            )


        return
            result
    }
}
