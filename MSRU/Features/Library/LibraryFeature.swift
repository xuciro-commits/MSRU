//
//  LibraryFeature.swift
//  MSRU
//

import Foundation
import Observation
import AppFoundation


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
