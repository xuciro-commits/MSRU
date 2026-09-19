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
                        "radio",
                    group:
                        "Discover",
                    title:
                        "Radio",
                    systemImage:
                        "dot.radiowaves.left.and.right",
                    route:
                        .section(
                            .radio
                        ),
                    order:
                        30
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
                        "radio",
                    route:
                        .section(
                            .radio
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


            // MARK: Radio

            RouteDestination(
                id:
                    "radio",
                route:
                    SceneRoute
                        .section(
                            .radio
                        )
            ) {
                _ in

                ContentUnavailableView(
                    "Radio",
                    systemImage:
                        "dot.radiowaves.left.and.right",
                    description:
                        Text(
                            "Radio providers and continuous playback will land in a later milestone."
                        )
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity
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
