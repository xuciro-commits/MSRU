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
                ListenNowFeature.self
            )

            builder.add(
                BrowseFeature.self
            )

            builder.add(
                LibraryFeature.self
            )

            builder.add(
                AlbumsFeature.self
            )

            builder.add(
                ArtistsFeature.self
            )

            builder.add(
                PlaylistsFeature.self
            )

            builder.add(
                RadioFeature.self
            )

            builder.add(
                AddMusicFeature.self
            )

            builder.add(
                SettingsFeature.self
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
}

