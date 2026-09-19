//
//  MultiSceneApplicationCommandRuntimeTests.swift
//  MSRUTests
//

import Testing
import AppFoundation

@testable import MSRU


@MainActor
struct MultiSceneApplicationCommandRuntimeTests {

    // MARK: - Route

    @Test
    func successfulRouteReturnsResolvedScene() {

        let sceneID =
            SceneID()


        let sceneRuntime =
            RecordingMultiSceneRuntime()

        sceneRuntime.routeResult =
            sceneID


        let handler =
            MultiSceneApplicationCommandHandler(
                runtime:
                    sceneRuntime
            )


        let request =
            SceneRoutingRequest(
                route:
                    testRoute
            )


        let result =
            handler
                .handle(
                    .route(
                        request
                    )
                )


        #expect(
            result
            ==
            .scene(
                sceneID
            )
        )


        #expect(
            sceneRuntime.routedRequests
            ==
            [
                request
            ]
        )
    }


    // MARK: - Explicit Missing Scene

    @Test
    func missingExplicitSceneReturnsSceneNotFound() {

        let missingSceneID =
            SceneID()


        let sceneRuntime =
            RecordingMultiSceneRuntime()


        let handler =
            MultiSceneApplicationCommandHandler(
                runtime:
                    sceneRuntime
            )


        let result =
            handler
                .handle(
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
    }


    // MARK: - Unresolved Generic Route

    @Test
    func unresolvedActiveOrNewRouteIsUnsupported() {

        let sceneRuntime =
            RecordingMultiSceneRuntime()


        let handler =
            MultiSceneApplicationCommandHandler(
                runtime:
                    sceneRuntime
            )


        let result =
            handler
                .handle(
                    .open(
                        testRoute
                    )
                )


        #expect(
            result
            ==
            .rejected(
                .unsupported
            )
        )
    }


    // MARK: - Open Scene

    @Test
    func openNewSceneUsesRuntimeCapability() {

        let openedSceneID =
            SceneID()


        let sceneRuntime =
            RecordingMultiSceneRuntime(
                openedSceneID:
                    openedSceneID
            )


        let handler =
            MultiSceneApplicationCommandHandler(
                runtime:
                    sceneRuntime
            )


        let result =
            handler
                .handle(
                    .openNewScene(
                        route:
                            testRoute
                    )
                )


        #expect(
            result
            ==
            .scene(
                openedSceneID
            )
        )


        #expect(
            sceneRuntime.openedRoutes
            ==
            [
                testRoute
            ]
        )
    }


    // MARK: - Activate Existing

    @Test
    func activatingExistingSceneReturnsScene() {

        let sceneID =
            SceneID()


        let sceneRuntime =
            RecordingMultiSceneRuntime()

        sceneRuntime.activationResult =
            true


        let handler =
            MultiSceneApplicationCommandHandler(
                runtime:
                    sceneRuntime
            )


        let result =
            handler
                .handle(
                    .activateScene(
                        sceneID
                    )
                )


        #expect(
            result
            ==
            .scene(
                sceneID
            )
        )


        #expect(
            sceneRuntime.activatedSceneIDs
            ==
            [
                sceneID
            ]
        )
    }


    // MARK: - Activate Missing

    @Test
    func activatingMissingSceneReturnsSceneNotFound() {

        let sceneID =
            SceneID()


        let sceneRuntime =
            RecordingMultiSceneRuntime()

        sceneRuntime.activationResult =
            false


        let handler =
            MultiSceneApplicationCommandHandler(
                runtime:
                    sceneRuntime
            )


        let result =
            handler
                .handle(
                    .activateScene(
                        sceneID
                    )
                )


        #expect(
            result
            ==
            .rejected(
                .sceneNotFound(
                    sceneID
                )
            )
        )
    }


    // MARK: - Runtime Gate

    @Test
    func runtimeDefersUntilActivated() {

        let resolvedSceneID =
            SceneID()


        let sceneRuntime =
            RecordingMultiSceneRuntime()

        sceneRuntime.routeResult =
            resolvedSceneID


        let runtime =
            MultiSceneApplicationCommandRuntime(
                runtime:
                    sceneRuntime
            )


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
            runtime.pendingCommandCount
            ==
            1
        )


        #expect(
            sceneRuntime.routedRequests
                .isEmpty
        )


        let results =
            runtime
                .activate()


        #expect(
            results
            ==
            [
                .scene(
                    resolvedSceneID
                )
            ]
        )


        #expect(
            runtime.pendingCommandCount
            ==
            0
        )


        #expect(
            sceneRuntime.routedRequests.count
            ==
            1
        )
    }


    // MARK: - Active Runtime

    @Test
    func activeRuntimeImmediatelyDispatches() {

        let openedSceneID =
            SceneID()


        let sceneRuntime =
            RecordingMultiSceneRuntime(
                openedSceneID:
                    openedSceneID
            )


        let runtime =
            MultiSceneApplicationCommandRuntime(
                runtime:
                    sceneRuntime,
                startsActive:
                    true
            )


        let result =
            runtime
                .send(
                    .newScene
                )


        #expect(
            result
            ==
            .scene(
                openedSceneID
            )
        )


        #expect(
            runtime.pendingCommandCount
            ==
            0
        )
    }
}


// MARK: - Test Route

/*
 现有 SceneRoute 仅作为 opaque payload。

 MultiScene infrastructure
 不解释该值的业务含义。
 */

private let testRoute =
    SceneRoute
        .section(
            .browse
        )


// MARK: - Recording Multi Scene Runtime

@MainActor
private final class RecordingMultiSceneRuntime:
    ApplicationMultiSceneRuntime {

    // MARK: Results

    var routeResult:
        SceneID?


    var activationResult =
        false


    private let openedSceneID:
        SceneID


    // MARK: Recording

    private(set) var routedRequests:
        [SceneRoutingRequest] = []


    private(set) var openedRoutes:
        [SceneRoute?] = []


    private(set) var activatedSceneIDs:
        [SceneID] = []


    // MARK: Init

    init(
        openedSceneID:
            SceneID = SceneID()
    ) {

        self.openedSceneID =
            openedSceneID
    }


    // MARK: Route

    func route(
        _ request:
            SceneRoutingRequest
    ) -> SceneID? {

        routedRequests
            .append(
                request
            )


        return
            routeResult
    }


    // MARK: Open

    func openNewScene(
        route:
            SceneRoute?
    ) -> SceneID {

        openedRoutes
            .append(
                route
            )


        return
            openedSceneID
    }


    // MARK: Activate

    func activateScene(
        _ sceneID:
            SceneID
    ) -> Bool {

        activatedSceneIDs
            .append(
                sceneID
            )


        return
            activationResult
    }
}
