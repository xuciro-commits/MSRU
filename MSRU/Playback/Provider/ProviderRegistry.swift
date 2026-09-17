//
//  ProviderRegistry.swift
//  MSRU
//

import Foundation


actor ProviderRegistry {

    // MARK: - Storage

    private var providers:
        [
            PlaybackProviderID:
            any PlaybackProvider
        ] = [:]


    private var providerOrder:
        [PlaybackProviderID] = []


    // MARK: - Init

    init(
        providers:
            [any PlaybackProvider] = []
    ) {

        for provider in providers {

            let id =
                provider
                    .descriptor
                    .id


            self.providers[id] =
                provider


            if !providerOrder
                .contains(id) {

                providerOrder
                    .append(id)
            }
        }
    }


    // MARK: - Register

    func register(
        _ provider:
            any PlaybackProvider
    ) {

        let id =
            provider
                .descriptor
                .id


        providers[id] =
            provider


        if !providerOrder
            .contains(id) {

            providerOrder
                .append(id)
        }
    }


    // MARK: - Unregister

    func unregister(
        _ id:
            PlaybackProviderID
    ) {

        providers[id] =
            nil


        providerOrder
            .removeAll {
                $0 == id
            }
    }


    // MARK: - Provider

    func provider(
        _ id:
            PlaybackProviderID
    ) -> (any PlaybackProvider)? {

        providers[id]
    }


    // MARK: - Descriptors

    func descriptors()
        -> [PlaybackProviderDescriptor] {

        providerOrder
            .compactMap {
                providers[$0]?
                    .descriptor
            }
    }


    // MARK: - Order

    func setProviderOrder(
        _ order:
            [PlaybackProviderID]
    ) {

        var normalized:
            [PlaybackProviderID] = []


        for id in order {

            guard
                providers[id] != nil
            else {
                continue
            }


            guard
                !normalized
                    .contains(id)
            else {
                continue
            }


            normalized.append(
                id
            )
        }


        /*
         没写进 order 的 Provider
         自动放到后面。
         */

        for id in providerOrder {

            guard
                providers[id] != nil
            else {
                continue
            }


            guard
                !normalized
                    .contains(id)
            else {
                continue
            }


            normalized.append(
                id
            )
        }


        providerOrder =
            normalized
    }


    // MARK: - Resolution Order

    func orderedProviders(
        preferred:
            PlaybackProviderID?
    ) -> [any PlaybackProvider] {

        var ids =
            providerOrder


        /*
         用户明确指定的 Provider
         放到最前。
         */

        if let preferred,
           providers[preferred] != nil {

            ids.removeAll {
                $0 == preferred
            }

            ids.insert(
                preferred,
                at: 0
            )
        }


        return ids
            .compactMap {
                providers[$0]
            }
    }
}
