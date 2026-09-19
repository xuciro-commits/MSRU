//
//  SingleSceneApplicationCommandRuntimeTests.swift
//  MSRUTests
//

import Testing
import AppFoundation

@testable import MSRU


@MainActor
struct SingleSceneApplicationCommandRuntimeTests {

    // MARK: - Deferred Before Attach

    @Test
    func commandBeforeSceneAttachmentIsDeferred() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let result =
            runtime
                .send(
                    .open(
                        testRoute
                    )
                )


        #expect(
            result
            ==
            .deferred
        )


        #expect(
            runtime.pendingCommandCount
            ==
            1
        )


        #expect(
            !runtime.canActivate
        )


        #expect(
            !runtime.isActive
        )
    }


    // MARK: - Attach Does Not Activate

    @Test
    func attachingSceneDoesNotImplicitlyActivateRuntime() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let scene =
            RecordingApplicationSceneRuntime()


        runtime
            .attach(
                scene
            )


        #expect(
            runtime.canActivate
        )


        #expect(
            !runtime.isActive
        )


        #expect(
            scene.commands
                .isEmpty
        )
    }


    // MARK: - Activate Flush

    @Test
    func activationFlushesDeferredCommands() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let scene =
            RecordingApplicationSceneRuntime()


        runtime
            .send(
                .open(
                    testRoute
                )
            )


        runtime
            .attach(
                scene
            )


        let results =
            runtime
                .activate()


        #expect(
            runtime.isActive
        )


        #expect(
            runtime.pendingCommandCount
            ==
            0
        )


        #expect(
            results
            ==
            [
                .scene(
                    scene.id
                )
            ]
        )


        #expect(
            scene.commands
            ==
            [
                .navigate(
                    testRoute
                )
            ]
        )
    }


    // MARK: - Immediate Dispatch

    @Test
    func activeRuntimeImmediatelyRoutesCommand() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let scene =
            RecordingApplicationSceneRuntime()


        runtime
            .attach(
                scene
            )


        runtime
            .activate()


        let result =
            runtime
                .send(
                    .open(
                        testRoute
                    )
                )


        #expect(
            result
            ==
            .scene(
                scene.id
            )
        )


        #expect(
            scene.commands
            ==
            [
                .navigate(
                    testRoute
                )
            ]
        )
    }


    // MARK: - Explicit Scene

    @Test
    func explicitAttachedSceneRoutesSuccessfully() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let scene =
            RecordingApplicationSceneRuntime()


        runtime
            .attach(
                scene
            )


        runtime
            .activate()


        let result =
            runtime
                .send(
                    .open(
                        testRoute,
                    target:
                        .scene(
                            scene.id
                        )
                )
            )


        #expect(
            result
            ==
            .scene(
                scene.id
            )
        )
    }


    // MARK: - Missing Scene

    @Test
    func unknownExplicitSceneIsRejected() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let scene =
            RecordingApplicationSceneRuntime()


        let missingSceneID =
            SceneID()


        runtime
            .attach(
                scene
            )


        runtime
            .activate()


        let result =
            runtime
                .send(
                    .open(
                        testRoute,
                    target:
                        .scene(
                            missingSceneID
                        )
                )
            )


        #expect(
            result
            ==
            .rejected(
                .sceneNotFound(
                    missingSceneID
                )
            )
        )


        #expect(
            scene.commands
                .isEmpty
        )
    }


    // MARK: - New Scene Unsupported

    @Test
    func newSceneCapabilityIsUnsupported() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let scene =
            RecordingApplicationSceneRuntime()


        runtime
            .attach(
                scene
            )


        runtime
            .activate()


        let result =
            runtime
                .send(
                    .newScene
                )


        #expect(
            result
            ==
            .rejected(
                .unsupported
            )
        )
    }


    // MARK: - Suspend

    @Test
    func suspendedRuntimeBuffersUntilReactivated() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let scene =
            RecordingApplicationSceneRuntime()


        runtime
            .attach(
                scene
            )


        runtime
            .activate()


        runtime
            .suspend()


        let deferred =
            runtime
                .send(
                    .open(
                        testRoute
                    )
                )


        #expect(
            deferred
            ==
            .deferred
        )


        #expect(
            scene.commands
                .isEmpty
        )


        runtime
            .activate()


        #expect(
            scene.commands
            ==
            [
                .navigate(
                    testRoute
                )
            ]
        )
    }


    // MARK: - Detach

    @Test
    func detachedRuntimeCannotActivateUntilNewSceneAttached() {

        let runtime =
            SingleSceneApplicationCommandRuntime()


        let firstScene =
            RecordingApplicationSceneRuntime()


        runtime
            .attach(
                firstScene
            )


        runtime
            .activate()


        runtime
            .detach()


        #expect(
            !runtime.canActivate
        )


        #expect(
            !runtime.isActive
        )


        runtime
            .send(
                .open(
                    testRoute
                )
            )


        let noResults =
            runtime
                .activate()


        #expect(
            noResults
                .isEmpty
        )


        #expect(
            runtime.pendingCommandCount
            ==
            1
        )


        let secondScene =
            RecordingApplicationSceneRuntime()


        runtime
            .attach(
                secondScene
            )


        runtime
            .activate()


        #expect(
            secondScene.commands
            ==
            [
                .navigate(
                    testRoute
                )
            ]
        )
    }
}


// MARK: - Test Route

private let testRoute =
    SceneRoute
        .section(
            .browse
        )


// MARK: - Recording Scene Runtime

private final class RecordingApplicationSceneRuntime:
    ApplicationSceneRuntime {

    let id =
        MSRU.SceneID()


    private(set) var commands:
        [MSRU.SceneCommand] = []


    func send(
        _ command:
            MSRU.SceneCommand
    ) {

        commands
            .append(
                command
            )
    }
}
