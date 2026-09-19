//
//  LibraryFeature+Presentation.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI


// MARK: - Application Presentation

extension LibraryFeature:
    ApplicationFeaturePresentation {

    typealias PresentationContext =
        SceneModel


    @MainActor
    static var routeDestinations:
        [
            RouteDestination<
                Route,
                PresentationContext
            >
        ] {

        [

            RouteDestination(
                id:
                    "library",
                route:
                    SceneRoute
                        .section(
                            .library
                        )
            ) {
                scene in

                LibraryFeatureDestination(
                    scene:
                        scene
                )
            }
        ]
    }
}


// MARK: - Destination Adapter

private struct LibraryFeatureDestination:
    View {

    @Bindable
    var scene:
        SceneModel


    var body:
        some View {

        LibraryView(
            feature:
                scene
                    .libraryFeature,
            localStore:
                scene
                    .application
                    .localLibrary,
            playback:
                scene
                    .application
                    .playback,
            selectedLocalTrack:
                $scene
                    .selectedLocalTrack,
            onAddMusic: {

                scene
                    .send(
                        .navigate(
                            .section(
                                .addMusic
                            )
                        )
                    )
            }
        )
    }
}
