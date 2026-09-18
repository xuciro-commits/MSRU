//
//  BrowseFeature.swift
//  MSRU
//

import Foundation
import Observation


// MARK: - Feature Definition

enum BrowseFeature {

    // MARK: State

    @MainActor
    @Observable
    final class State {

        fileprivate(set) var query:
            String

        fileprivate(set) var results:
            [OpenverseAudio]

        fileprivate(set) var isLoading:
            Bool

        fileprivate(set) var errorMessage:
            String?

        fileprivate var hasAppeared =
            false


        init(
            query:
                String = "mozart",
            results:
                [OpenverseAudio] = [],
            isLoading:
                Bool = false,
            errorMessage:
                String? = nil
        ) {

            self.query =
                query

            self.results =
                results

            self.isLoading =
                isLoading

            self.errorMessage =
                errorMessage
        }
    }


    // MARK: Action

    enum Action {

        case appeared

        case queryChanged(
            String
        )

        case retryRequested

        case searchRequested(
            String
        )

        case searchSucceeded(
            query: String,
            results: [OpenverseAudio]
        )

        case searchFailed(
            query: String,
            message: String
        )


        case playPauseRequested(
            OpenverseAudio
        )

        case playNextRequested(
            OpenverseAudio
        )

        case addToQueueRequested(
            OpenverseAudio
        )

        case libraryToggleRequested(
            OpenverseAudio
        )

        case libraryMutationFinished
    }


    // MARK: Service

    @MainActor
    struct Service {

        private enum TaskID {

            static let debounce =
                "browse.search.debounce"

            static let request =
                "browse.search.request"
        }


        private let searchClient:
            OpenverseSearchClient

        private let playback:
            PlaybackController

        private let library:
            LibraryStore


        init(
            searchClient:
                OpenverseSearchClient,
            playback:
                PlaybackController,
            library:
                LibraryStore
        ) {

            self.searchClient =
                searchClient

            self.playback =
                playback

            self.library =
                library
        }


        // MARK: Derived UI State

        var isPlaying:
            Bool {

            playback
                .isPlaying
        }


        func isCurrent(
            _ item:
                OpenverseAudio
        ) -> Bool {

            playback
                .currentItem?
                .openverseTrack?
                .id
            == item.id
        }


        func isSaved(
            _ item:
                OpenverseAudio
        ) -> Bool {

            library
                .contains(
                    openverse:
                        item
                )
        }


        // MARK: Handle

        func handle(
            _ action:
                Action,
            state:
                State
        ) -> [FeatureTask<Action>] {

            switch action {

            // MARK: Lifecycle

            case .appeared:

                guard
                    !state.hasAppeared
                else {
                    return []
                }


                state.hasAppeared =
                    true


                let cleaned =
                    state.query
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )


                if cleaned.isEmpty {

                    state.query =
                        "mozart"
                }


                /*
                 Preview 可以预先注入 results。

                 如果已有结果，
                 appeared 不应该再启动搜索。
                 */

                guard
                    state.results.isEmpty
                else {
                    return []
                }


                let query =
                    normalizedQuery(
                        state.query
                    )


                guard
                    !query.isEmpty
                else {
                    return []
                }


                state.isLoading =
                    true

                state.errorMessage =
                    nil


                return [
                    requestTask(
                        query:
                            query
                    )
                ]


            // MARK: Query

            case .queryChanged(
                let value
            ):

                state.query =
                    value

                state.errorMessage =
                    nil

                state.isLoading =
                    false


                let query =
                    normalizedQuery(
                        value
                    )


                guard
                    !query.isEmpty
                else {

                    state.results = []

                    return [
                        .cancel(
                            id:
                                TaskID.debounce
                        ),
                        .cancel(
                            id:
                                TaskID.request
                        )
                    ]
                }


                return [

                    .cancel(
                        id:
                            TaskID.request
                    ),

                    .run(
                        id:
                            TaskID.debounce,
                        cancelInFlight:
                            true
                    ) {
                        send in

                        do {

                            try await Task
                                .sleep(
                                    nanoseconds:
                                        350_000_000
                                )

                        } catch {

                            return
                        }


                        guard
                            !Task.isCancelled
                        else {
                            return
                        }


                        send(
                            .searchRequested(
                                query
                            )
                        )
                    }
                ]


            // MARK: Retry

            case .retryRequested:

                let query =
                    normalizedQuery(
                        state.query
                    )


                guard
                    !query.isEmpty
                else {
                    return []
                }


                state.isLoading =
                    true

                state.errorMessage =
                    nil


                return [

                    .cancel(
                        id:
                            TaskID.debounce
                    ),

                    requestTask(
                        query:
                            query
                    )
                ]


            // MARK: Begin Search

            case .searchRequested(
                let query
            ):

                guard
                    normalizedQuery(
                        state.query
                    )
                    == query
                else {
                    return []
                }


                state.isLoading =
                    true

                state.errorMessage =
                    nil


                return [
                    requestTask(
                        query:
                            query
                    )
                ]


            // MARK: Search Success

            case .searchSucceeded(
                let query,
                let results
            ):

                guard
                    normalizedQuery(
                        state.query
                    )
                    == query
                else {
                    return []
                }


                state.results =
                    results

                state.isLoading =
                    false

                state.errorMessage =
                    nil


                return []


            // MARK: Search Failure

            case .searchFailed(
                let query,
                let message
            ):

                guard
                    normalizedQuery(
                        state.query
                    )
                    == query
                else {
                    return []
                }


                state.results = []

                state.isLoading =
                    false

                state.errorMessage =
                    message


                return []


            // MARK: Playback

            case .playPauseRequested(
                let item
            ):

                playback
                    .toggle(
                        openverse:
                            item,
                        queue:
                            state.results
                    )


                return []


            case .playNextRequested(
                let item
            ):

                playback
                    .playNext(
                        openverse:
                            item
                    )


                return []


            case .addToQueueRequested(
                let item
            ):

                playback
                    .addToQueue(
                        openverse:
                            item
                    )


                return []


            // MARK: Library

            case .libraryToggleRequested(
                let item
            ):

                let isSaved =
                    library
                        .contains(
                            openverse:
                                item
                        )


                return [

                    .run(
                        id:
                            "browse.library.\(item.id)",
                        cancelInFlight:
                            true
                    ) {
                        send in

                        if isSaved {

                            await library
                                .remove(
                                    openverse:
                                        item
                                )

                        } else {

                            await library
                                .add(
                                    openverse:
                                        item
                                )
                        }


                        send(
                            .libraryMutationFinished
                        )
                    }
                ]


            case .libraryMutationFinished:

                /*
                 LibraryStore 自身是 Observable。

                 View 对 isSaved 的读取会跟踪
                 LibraryStore.tracks。

                 所以这里不复制一份 saved IDs。
                 */

                return []
            }
        }


        // MARK: Search Task

        private func requestTask(
            query:
                String
        ) -> FeatureTask<Action> {

            .run(
                id:
                    TaskID.request,
                cancelInFlight:
                    true
            ) {
                send in

                do {

                    let results =
                        try await searchClient
                            .search(
                                query
                            )


                    guard
                        !Task.isCancelled
                    else {
                        return
                    }


                    send(
                        .searchSucceeded(
                            query:
                                query,
                            results:
                                results
                        )
                    )

                } catch is CancellationError {

                    return

                } catch {

                    guard
                        !Task.isCancelled
                    else {
                        return
                    }


                    send(
                        .searchFailed(
                            query:
                                query,
                            message:
                                error.localizedDescription
                        )
                    )
                }
            }
        }


        // MARK: Query

        private func normalizedQuery(
            _ value:
                String
        ) -> String {

            value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
        }
    }
}


// MARK: - Runtime Host

@MainActor
final class BrowseFeatureHost {

    private struct RunningTask {

        let token:
            UUID

        let task:
            Task<Void, Never>
    }


    let state:
        BrowseFeature.State


    private let service:
        BrowseFeature.Service


    private var runningTasks:
        [String: RunningTask] = [:]


    // MARK: - Init

    init(
        state:
            BrowseFeature.State,
        service:
            BrowseFeature.Service
    ) {

        self.state =
            state

        self.service =
            service
    }


    convenience init(
        service:
            BrowseFeature.Service
    ) {

        self.init(
            state:
                BrowseFeature.State(),
            service:
                service
        )
    }


    // MARK: - Send

    func send(
        _ action:
            BrowseFeature.Action
    ) {

        let tasks =
            service.handle(
                action,
                state:
                    state
            )


        for task in tasks {

            execute(
                task
            )
        }
    }


    // MARK: - Derived State

    var isPlaying:
        Bool {

        service
            .isPlaying
    }


    func isCurrent(
        _ item:
            OpenverseAudio
    ) -> Bool {

        service
            .isCurrent(
                item
            )
    }


    func isSaved(
        _ item:
            OpenverseAudio
    ) -> Bool {

        service
            .isSaved(
                item
            )
    }


    // MARK: - Tasks

    func cancelAll() {

        for runningTask
            in runningTasks.values {

            runningTask
                .task
                .cancel()
        }


        runningTasks
            .removeAll()
    }


    private func execute(
        _ featureTask:
            FeatureTask<
                BrowseFeature.Action
            >
    ) {

        switch featureTask.kind {

        case .cancel(
            let id
        ):

            runningTasks[
                id
            ]?
            .task
            .cancel()


            runningTasks[
                id
            ] = nil


        case .run(
            let id,
            let cancelInFlight,
            let priority,
            let operation
        ):

            if
                let id,
                cancelInFlight {

                runningTasks[
                    id
                ]?
                .task
                .cancel()


                runningTasks[
                    id
                ] = nil
            }


            let token =
                UUID()


            let task =
                Task(
                    priority:
                        priority
                ) {
                    [weak self]
                    in

                    guard
                        let self
                    else {
                        return
                    }


                    await operation {
                        [weak self]
                        action in

                        self?
                            .send(
                                action
                            )
                    }


                    guard
                        let id
                    else {
                        return
                    }


                    finishTask(
                        id:
                            id,
                        token:
                            token
                    )
                }


            if let id {

                runningTasks[
                    id
                ] =
                    RunningTask(
                        token:
                            token,
                        task:
                            task
                    )
            }
        }
    }


    private func finishTask(
        id:
            String,
        token:
            UUID
    ) {

        guard
            runningTasks[
                id
            ]?
            .token
            == token
        else {
            return
        }


        runningTasks[
            id
        ] = nil
    }
}
