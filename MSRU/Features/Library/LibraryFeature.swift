//
//  LibraryFeature.swift
//  MSRU
//

import Foundation
import Observation
import SwiftUI
import AppFoundation
import AppFoundationUI
import MusicLibrary
import MusicPlayback


// MARK: - Feature

enum LibraryFeature:
    Feature {

    // MARK: State

    @MainActor
    @Observable
    final class State {

        fileprivate(set) var pendingRemovalIDs:
            Set<UUID> = []


        init(
            pendingRemovalIDs:
                Set<UUID> = []
        ) {

            self.pendingRemovalIDs =
                pendingRemovalIDs
        }
    }


    // MARK: Action

    enum Action {
        case playRequested(id: UUID)
        case playNextRequested(id: UUID)
        case enqueueRequested(id: UUID)

        case removeRequested(
            id:
                UUID
        )

        case removeFinished(
            id:
                UUID
        )
    }


    // MARK: Initial State

    @MainActor
    static func makeInitialState()
        -> State {

        State()
    }


    // MARK: Service

    @MainActor
    struct Service:
        FeatureService {

        private enum TaskID {

            static func remove(
                _ id:
                    UUID
            ) -> FeatureTaskID {

                "library.remove.\(id)"
            }
        }


        // MARK: Dependency

        @Dependency(
            \.library
        )
        private var library:
            LibraryStore


        @Dependency(\.playback) private var playback: PlaybackController

        // MARK: Init

        init() {}


        // MARK: Projection

        var tracks:
            [LibraryTrack] {

            library
                .tracks
        }


        var isLoading:
            Bool {

            library
                .isLoading
        }


        var isSaving:
            Bool {

            library
                .isSaving
        }


        var errorMessage:
            String? {

            library
                .errorMessage
        }


        var libraryStore:
            LibraryStore {

            library
        }


        // MARK: Handle

        func handle(
            _ action:
                Action,
            state:
                State
        ) -> [FeatureTask<Action>] {

            switch action {
            case .playRequested(let id):
                guard let track = library.track(id: id), let item = PlaybackItem(library: track) else { return [] }
                if playback.currentItem?.id == item.id {
                    playback.toggle()
                } else {
                    playback.play(item, context: library.tracks.compactMap { PlaybackItem(library: $0) })
                }
                return []
            case .playNextRequested(let id):
                guard let track = library.track(id: id), let item = PlaybackItem(library: track) else { return [] }
                playback.playNext(item)
                return []
            case .enqueueRequested(let id):
                guard let track = library.track(id: id), let item = PlaybackItem(library: track) else { return [] }
                playback.addToQueue(item)
                return []

            // MARK: Remove

            case .removeRequested(
                let id
            ):

                guard
                    library.contains(
                        id:
                            id
                    )
                else {

                    return []
                }


                guard
                    !state
                        .pendingRemovalIDs
                        .contains(
                            id
                        )
                else {

                    return []
                }


                state
                    .pendingRemovalIDs
                    .insert(
                        id
                    )


                return [

                    .run(
                        id:
                            TaskID.remove(
                                id
                            ),
                        cancelInFlight:
                            true
                    ) {
                        send in

                        await library
                            .remove(
                                id:
                                    id
                            )


                        guard
                            !Task.isCancelled
                        else {

                            return
                        }


                        send(
                            .removeFinished(
                                id:
                                    id
                            )
                        )
                    }
                ]


            // MARK: Remove Finished

            case .removeFinished(
                let id
            ):

                state
                    .pendingRemovalIDs
                    .remove(
                        id
                    )


                return []
            }
        }
    }
}


// MARK: - Runtime Projection

@MainActor
extension FeatureHost
where F == LibraryFeature {

    var tracks:
        [LibraryTrack] {

        service
            .tracks
    }


    var isLoading:
        Bool {

        service
            .isLoading
    }


    var isSaving:
        Bool {

        service
            .isSaving
    }


    var errorMessage:
        String? {

        service
            .errorMessage
    }


    var libraryStore:
        LibraryStore {

        service
            .libraryStore
    }


    func isRemoving(
        _ track:
            LibraryTrack
    ) -> Bool {

        state
            .pendingRemovalIDs
            .contains(
                track.id
            )
    }
}

// MARK: - Application Contribution

extension LibraryFeature: ApplicationFeature {

    typealias Route = SceneRoute

    nonisolated static var contributions: FeatureContribution<Route> {
        FeatureContribution(
            sidebar: [
                SidebarContribution(
                    id: "library",
                    group: "Library",
                    title: "Songs",
                    systemImage: "music.note",
                    route: SceneRoute.section(.library),
                    order: 100
                )
            ],
            routes: [
                RouteContribution(
                    id: "library",
                    route: SceneRoute.section(.library)
                )
            ]
        )
    }
}

// MARK: - Application Presentation

extension LibraryFeature: ApplicationFeaturePresentation {

    typealias PresentationContext = SceneModel

    static var routeDestinations: [RouteDestination<SceneRoute, SceneModel>] {
        [
            RouteDestination(
                id: "library",
                route: .section(.library),
                workspace: { scene in
                    WorkspacePresentation(
                        identity: WorkspaceIdentity(
                            title: "Songs",
                            systemImage: "music.note"
                        )
                    ) { _ in
                        LibraryFeatureDestination(scene: scene)
                    }
                }
            )
        ]
    }
}

// MARK: - Destination Adapter

private struct LibraryFeatureDestination: View {

    @Bindable var scene: SceneModel

    var body: some View {
        LibraryView(
            feature: scene.libraryFeature,
            localStore: scene.application.localLibrary,
            subsonicServers: scene.application.subsonicServers,
            playback: scene.application.playback,
            selectedLocalTrack: Binding(
                get: { scene.selectedLocalTrack },
                set: { scene.select(localTrack: $0) }
            ),
            selectedLibraryTrack: Binding(
                get: { scene.selectedLibraryTrack },
                set: { scene.select(libraryTrack: $0) }
            ),
            selectedSourceID: Binding(
                get: { scene.selectedSourceFilter },
                set: { scene.selectedSourceFilter = $0 }
            ),
            onAddMusic: {
                scene.send(.navigate(.section(.addMusic)))
            }
        )
    }
}

#Preview("Library Destination") {
    LibraryFeatureDestination(scene: MSRUPreviewData.makeScene(section: .library))
        .frame(width: 900, height: 650)
}

