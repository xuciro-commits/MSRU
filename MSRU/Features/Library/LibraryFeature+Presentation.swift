//
//  LibraryFeature+Presentation.swift
//  MSRU
//

import Observation
import SwiftUI

import AppFoundationUI
import AppFoundation


// MARK: - Application Presentation

extension LibraryFeature:
    ApplicationFeaturePresentation {

    typealias PresentationContext =
        SceneModel


    static var routeDestinations:
        [
            RouteDestination<
                SceneRoute,
                SceneModel
            >
        ] {

        [
            RouteDestination(
                id:
                    "library",
                route:
                    .section(
                        .library
                    ),
                workspace: {
                    scene in

                    WorkspacePresentation(
                        identity:
                            WorkspaceIdentity(
                                title:
                                    "Library",
                                systemImage:
                                    "music.note.list"
                            )
                    ) {
                        _ in

                        LibraryFeatureDestination(
                            scene:
                                scene
                        )
                    }
                }
            )
        ]
    }
}


// MARK: - Destination Adapter

private struct LibraryFeatureDestination:
    View {

    @Bindable var scene:
        SceneModel


    var body:
        some View {

        LibraryView(
            feature:
                scene.libraryFeature,
            localStore:
                scene.application.localLibrary,
            playback:
                scene.application.playback,
            selectedLocalTrack:
                $scene.selectedLocalTrack,
            onAddMusic: {

                scene.send(
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

#Preview("Library Destination") {
    LibraryFeatureDestination(scene: MSRUPreviewData.makeScene(section: .library))
        .frame(width: 900, height: 650)
}
