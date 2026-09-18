//
//  BrowseFeature.swift
//  MSRU
//

import Foundation
import Observation


// MARK: - Feature Definition

enum BrowseFeature:
    Feature {

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

        // MARK: Task IDs

        private enum TaskID {

            static let debounce:
                FeatureTaskID =
                    "browse.search.debounce"


            static let request:
                FeatureTaskID =
                    "browse.search.request"
        }


        // MARK: Dependencies

        @Dependency(
            \.openverseSearch
        )
        private var searchClient:
            OpenverseSearchClient


        @Dependency(
            \.playback
        )
        private var playback:
            PlaybackController


        @Dependency(
            \.library
        )
        private var library:
            LibraryStore


        // MARK: Init

        /*
         正式 Runtime。

         Dependencies 来自创建 Service 时
         所处的 DependencyValues scope。
         */

        init() {}


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

                    state.results =
                        []


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

                    /*
                     新输入意味着当前 request 已经过期。
                     */

                    .cancel(
                        id:
                            TaskID.request
                    ),


                    /*
                     debounce 本身使用同一个 ID，
                     cancelInFlight 会替换旧 debounce。
                     */

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

                /*
                 debounce 完成时 query 可能已经改变。

                 只有它仍然对应当前输入，
                 才允许真正发起 request。
                 */

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

                /*
                 防止已经过期的网络响应
                 覆盖更新后的搜索结果。
                 */

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


                state.results =
                    []


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


                        guard
                            !Task.isCancelled
                        else {

                            return
                        }


                        send(
                            .libraryMutationFinished
                        )
                    }
                ]


            case .libraryMutationFinished:

                /*
                 LibraryStore 自身是 Observable。

                 View 对 isSaved 的读取
                 会观察同一个 application-scoped
                 LibraryStore。

                 所以 Browse State 不复制 saved IDs。
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


// MARK: - Browse Runtime Projection

/*
 Generic FeatureHost 不知道任何 Browse 业务。

 FeatureHost 只负责：

 State
 Service
 Action dispatch
 FeatureTask runtime
 cancellation
 dependencies

 Browse 自己需要的 UI projection
 留在 BrowseFeature 所在文件中。
 */

@MainActor
extension FeatureHost
where F == BrowseFeature {

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
}
