//
//  ApplicationCommandCenterTests.swift
//  MSRUTests
//

import Testing

@testable import MSRU


@MainActor
struct ApplicationCommandCenterTests {

    // MARK: - Single Dispatch

    @Test
    func singleCommandIsForwardedToHandler() {

        let handler =
            RecordingApplicationCommandHandler()

        let center =
            ApplicationCommandCenter(
                handler:
                    handler
            )

        let command =
            ApplicationCommand
                .open(
                    .section(
                        .browse
                    )
                )


        let result =
            center
                .send(
                    command
                )


        #expect(
            handler.commands
            ==
            [
                command
            ]
        )

        #expect(
            result
            ==
            .handled
        )
    }


    // MARK: - Result Preservation

    @Test
    func handlerResultIsReturnedWithoutTranslation() {

        let sceneID =
            SceneID()

        let handler =
            RecordingApplicationCommandHandler(
                result:
                    .scene(
                        sceneID
                    )
            )

        let center =
            ApplicationCommandCenter(
                handler:
                    handler
            )


        let result =
            center
                .send(
                    .newScene
                )


        #expect(
            result
            ==
            .scene(
                sceneID
            )
        )
    }


    // MARK: - Rejection Preservation

    @Test
    func rejectionIsReturnedWithoutTranslation() {

        let missingSceneID =
            SceneID()

        let handler =
            RecordingApplicationCommandHandler(
                result:
                    .rejected(
                        .sceneNotFound(
                            missingSceneID
                        )
                    )
            )

        let center =
            ApplicationCommandCenter(
                handler:
                    handler
            )


        let result =
            center
                .send(
                    .activateScene(
                        missingSceneID
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


    // MARK: - Batch Dispatch

    @Test
    func batchCommandsPreserveOrder() {

        let handler =
            RecordingApplicationCommandHandler()

        let center =
            ApplicationCommandCenter(
                handler:
                    handler
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
                    ),
                    target:
                        .new
                ),

                .newScene
            ]


        let results =
            center
                .send(
                    commands
                )


        #expect(
            handler.commands
            ==
            commands
        )

        #expect(
            results
            ==
            [
                .handled,
                .handled,
                .handled
            ]
        )
    }


    // MARK: - Route Convenience

    @Test
    func openConvenienceBuildsRoutingCommand() {

        let sceneID =
            SceneID()

        let command =
            ApplicationCommand
                .open(
                    .section(
                        .settings
                    ),
                    target:
                        .scene(
                            sceneID
                        )
                )


        #expect(
            command
            ==
            .route(
                SceneRoutingRequest(
                    route:
                        .section(
                            .settings
                        ),
                    target:
                        .scene(
                            sceneID
                        )
                )
            )
        )
    }


    // MARK: - New Scene Convenience

    @Test
    func newSceneConvenienceUsesDefaultRoute() {

        #expect(
            ApplicationCommand
                .newScene
            ==
            .openNewScene(
                route:
                    nil
            )
        )
    }
}


// MARK: - Recording Handler

@MainActor
private final class RecordingApplicationCommandHandler:
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
