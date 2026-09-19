//
//  ApplicationLifecycleRuntimeTests.swift
//  MSRUTests
//

import Testing

@testable import MSRU


@MainActor
struct ApplicationLifecycleRuntimeTests {

    // MARK: - Initial

    @Test
    func lifecycleStartsInitialized() {

        let commands =
            RecordingCommandLifecycle()


        let lifecycle =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commands
            )


        #expect(
            lifecycle.phase
            ==
            .initialized
        )
    }


    // MARK: - Bootstrap

    @Test
    func beginBootstrapTransitionsToBootstrapping() {

        let commands =
            RecordingCommandLifecycle()


        let lifecycle =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commands
            )


        let result =
            lifecycle
                .beginBootstrap()


        #expect(
            result
            ==
            .transitioned(
                to:
                    .bootstrapping,
                commandResults:
                    []
            )
        )


        #expect(
            lifecycle.phase
            ==
            .bootstrapping
        )
    }


    // MARK: - Ready Before Bootstrap

    @Test
    func readyBeforeBootstrapIsRejected() {

        let commands =
            RecordingCommandLifecycle()


        let lifecycle =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commands
            )


        let result =
            lifecycle
                .markReady()


        #expect(
            result
            ==
            .blocked(
                .bootstrapNotStarted
            )
        )


        #expect(
            commands.activationCount
            ==
            0
        )
    }


    // MARK: - Runtime Capability

    @Test
    func readyRequiresCommandRuntimeCapability() {

        let commands =
            RecordingCommandLifecycle(
                canActivate:
                    false
            )


        let lifecycle =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commands
            )


        lifecycle
            .beginBootstrap()


        let result =
            lifecycle
                .markReady()


        #expect(
            result
            ==
            .blocked(
                .commandRuntimeUnavailable
            )
        )


        #expect(
            lifecycle.phase
            ==
            .bootstrapping
        )
    }


    // MARK: - Ready

    @Test
    func readyActivatesCommandRuntime() {

        let commands =
            RecordingCommandLifecycle(
                activationResults:
                    [
                        .handled
                    ]
            )


        let lifecycle =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commands
            )


        lifecycle
            .beginBootstrap()


        let result =
            lifecycle
                .markReady()


        #expect(
            result
            ==
            .transitioned(
                to:
                    .ready,
                commandResults:
                    [
                        .handled
                    ]
            )
        )


        #expect(
            lifecycle.phase
            ==
            .ready
        )


        #expect(
            commands.activationCount
            ==
            1
        )
    }


    // MARK: - Idempotent Ready

    @Test
    func repeatedReadyDoesNotReactivateRuntime() {

        let commands =
            RecordingCommandLifecycle()


        let lifecycle =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commands
            )


        lifecycle
            .beginBootstrap()


        lifecycle
            .markReady()


        let second =
            lifecycle
                .markReady()


        #expect(
            second
            ==
            .unchanged(
                .ready
            )
        )


        #expect(
            commands.activationCount
            ==
            1
        )
    }


    // MARK: - Suspend / Resume

    @Test
    func suspendAndResumeControlCommandRuntime() {

        let commands =
            RecordingCommandLifecycle()


        let lifecycle =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commands
            )


        lifecycle
            .beginBootstrap()


        lifecycle
            .markReady()


        let suspended =
            lifecycle
                .suspend()


        #expect(
            suspended
            ==
            .transitioned(
                to:
                    .suspended,
                commandResults:
                    []
            )
        )


        #expect(
            commands.suspensionCount
            ==
            1
        )


        let resumed =
            lifecycle
                .resume()


        #expect(
            resumed
            ==
            .transitioned(
                to:
                    .ready,
                commandResults:
                    []
            )
        )


        #expect(
            commands.activationCount
            ==
            2
        )
    }


    // MARK: - Terminate

    @Test
    func terminateIsFinal() {

        let commands =
            RecordingCommandLifecycle()


        let lifecycle =
            ApplicationLifecycleRuntime(
                commandRuntime:
                    commands
            )


        lifecycle
            .beginBootstrap()


        lifecycle
            .markReady()


        let terminated =
            lifecycle
                .terminate()


        #expect(
            terminated
            ==
            .transitioned(
                to:
                    .terminated,
                commandResults:
                    []
            )
        )


        #expect(
            lifecycle.phase
            ==
            .terminated
        )


        let retry =
            lifecycle
                .resume()


        #expect(
            retry
            ==
            .blocked(
                .terminated
            )
        )
    }
}


// MARK: - Recording Command Lifecycle

@MainActor
private final class RecordingCommandLifecycle:
    ApplicationCommandRuntimeLifecycle {

    var canActivate:
        Bool


    private(set) var isActive =
        false


    private(set) var activationCount =
        0


    private(set) var suspensionCount =
        0


    var activationResults:
        [ApplicationCommandResult]


    init(
        canActivate:
            Bool = true,
        activationResults:
            [ApplicationCommandResult] = []
    ) {

        self.canActivate =
            canActivate


        self.activationResults =
            activationResults
    }


    func activate()
        -> [ApplicationCommandResult] {

        guard
            canActivate
        else {

            return []
        }


        activationCount +=
            1


        isActive =
            true


        return
            activationResults
    }


    func suspend() {

        suspensionCount +=
            1


        isActive =
            false
    }
}
