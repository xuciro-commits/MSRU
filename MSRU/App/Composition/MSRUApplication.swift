//
//  MSRUApplication.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI


// MARK: - MSRU Application

@MainActor
enum MSRUApplication {

    // MARK: - Definition

    static let definition:
        ApplicationDefinition<
            SceneRoute,
            SceneModel
        > = {

            var builder =
                ApplicationDefinitionBuilder<
                    SceneRoute,
                    SceneModel
                >()


            // MARK: Feature Modules

            builder.add(
                BrowseFeature.self
            )


            builder.add(
                LibraryFeature.self
            )


            builder.add(
                RadioFeature.self
            )


            // MARK: Transitional Host Module

            builder.addHost(
                contribution:
                    transitionalHostContribution,
                routeDestinations:
                    transitionalHostDestinations
            )


            let definition =
                builder.build()


            #if DEBUG

            let validation =
                definition
                    .validate()


            assert(
                validation.isValid,
                validation.debugDescription
            )

            #endif


            return
                definition
        }()


    // MARK: - Transitional Host Structure

    private static var transitionalHostContribution:
        FeatureContribution<SceneRoute> {

        FeatureContribution(

            sidebar: [

                SidebarContribution(
                    id:
                        "listen-now",
                    group:
                        "Discover",
                    title:
                        "Listen Now",
                    systemImage:
                        "play.circle",
                    route:
                        .section(
                            .listenNow
                        ),
                    order:
                        10
                ),


                SidebarContribution(
                    id:
                        "add-music",
                    group:
                        "Library",
                    title:
                        "Add Music",
                    systemImage:
                        "plus.square.on.square",
                    route:
                        .section(
                            .addMusic
                        ),
                    order:
                        20
                )
            ],

            routes: [

                RouteContribution(
                    id:
                        "listen-now",
                    route:
                        .section(
                            .listenNow
                        )
                ),


                RouteContribution(
                    id:
                        "add-music",
                    route:
                        .section(
                            .addMusic
                        )
                ),


                RouteContribution(
                    id:
                        "settings",
                    route:
                        .section(
                            .settings
                        )
                )
            ]
        )
    }


    // MARK: - Transitional Host Presentation

    private static var transitionalHostDestinations:
        [
            RouteDestination<
                SceneRoute,
                SceneModel
            >
        ] {

        [

            // MARK: Listen Now

            RouteDestination(
                id:
                    "listen-now",
                route:
                    SceneRoute
                        .section(
                            .listenNow
                        )
            ) {
                scene in

                ListenNowView(
                    store:
                        scene
                            .application
                            .musicCatalog,
                    onSelect: {
                        item in

                        scene
                            .selectedMusicContent =
                            item
                    }
                )
            },


            // MARK: Add Music

            RouteDestination(
                id:
                    "add-music",
                route:
                    SceneRoute
                        .section(
                            .addMusic
                        )
            ) {
                scene in

                AddMusicView(
                    localStore:
                        scene
                            .application
                            .localLibrary,
                    appleMusicStore:
                        scene
                            .application
                            .musicLibrary,
                    onOpenLibrary: {

                        scene
                            .send(
                                .navigate(
                                    .section(
                                        .library
                                    )
                                )
                            )
                    }
                )
            },


            // MARK: Settings

            RouteDestination(
                id:
                    "settings",
                route:
                    SceneRoute
                        .section(
                            .settings
                        )
            ) {
                scene in

                SettingsView(
                    playback:
                        scene
                            .application
                            .playback,
                    providerManager:
                        scene
                            .application
                            .providerManager
                )
            }
        ]
    }
}
