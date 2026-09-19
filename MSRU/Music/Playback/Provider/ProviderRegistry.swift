//
//  ProviderRegistry.swift
//  MSRU
//

import Foundation


final class ProviderRegistry:
    @unchecked Sendable {

    private let lock =
        NSLock()

    private var storage:
        [
            PlaybackProviderID:
                any PlaybackProvider
        ] = [:]


    // MARK: - Register

    func register(
        _ provider:
            any PlaybackProvider
    ) {

        lock.lock()

        defer {
            lock.unlock()
        }


        storage[
            provider.id
        ] =
            provider
    }


    // MARK: - Remove

    func remove(
        _ id:
            PlaybackProviderID
    ) {

        lock.lock()

        defer {
            lock.unlock()
        }


        storage.removeValue(
            forKey:
                id
        )
    }


    // MARK: - Provider

    func provider(
        for id:
            PlaybackProviderID
    ) -> (
        any PlaybackProvider
    )? {

        lock.lock()

        defer {
            lock.unlock()
        }


        return storage[
            id
        ]
    }


    // MARK: - Candidates

    func candidates(
        for request:
            PlaybackRequest
    ) -> [
        any PlaybackProvider
    ] {

        lock.lock()

        let providers =
            Array(
                storage.values
            )

        lock.unlock()


        return providers
            .filter {
                $0.canResolve(
                    request
                )
            }
            .sorted {
                lhs,
                rhs in

                lhs.priority
                    > rhs.priority
            }
    }
}
