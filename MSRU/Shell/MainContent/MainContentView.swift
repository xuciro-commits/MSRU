//
//  MainContentView.swift
//  MSRU
//

import SwiftUI
import Observation

#if os(macOS)

import AppKit

#elseif os(iOS)

import UIKit

#endif


struct MainContentView:
    View {

    // MARK: - Scene

    @Bindable
    var scene:
        SceneModel


    // MARK: - Application

    private var application:
        ApplicationModel {

        scene
            .application
    }


    // MARK: - Body

    var body:
        some View {

        ZStack {

            platformBackground
                .ignoresSafeArea()


            page
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }


    // MARK: - Background

    private var platformBackground:
        Color {

        #if os(macOS)

        Color(
            nsColor:
                .windowBackgroundColor
        )


        #elseif os(iOS)

        Color(
            uiColor:
                .systemBackground
        )


        #else

        Color.clear

        #endif
    }


    // MARK: - Page

    @ViewBuilder
    private var page:
        some View {

        switch
            scene
                .navigation
                .section {

        // MARK: Listen Now

        case .listenNow:

            ListenNowView(
                store:
                    application
                        .musicCatalog,
                onSelect: {
                    item in

                    scene
                        .selectedMusicContent =
                        item
                }
            )


        // MARK: Browse

        case .browse:

            BrowseView(
                feature:
                    scene
                        .browse
            )


        // MARK: Radio

        case .radio:

            placeholder(
                title:
                    "Radio",
                systemImage:
                    "dot.radiowaves.left.and.right",
                description:
                    "Radio providers and continuous playback will land in a later milestone."
            )


        // MARK: Library

        case .library:

            LibraryView(
                feature:
                    scene
                        .libraryFeature,
                localStore:
                    application
                        .localLibrary,
                playback:
                    application
                        .playback,
                selectedLocalTrack:
                    $scene
                        .selectedLocalTrack,
                onAddMusic: {

                    scene
                        .navigation
                        .select(
                            .addMusic
                        )
                }
            )


        // MARK: Add Music

        case .addMusic:

            AddMusicView(
                localStore:
                    application
                        .localLibrary,
                appleMusicStore:
                    application
                        .musicLibrary,
                onOpenLibrary: {

                    scene
                        .navigation
                        .select(
                            .library
                        )
                }
            )


        // MARK: Settings

        case .settings:

            SettingsView(
                playback:
                    application
                        .playback,
                providerManager:
                    application
                        .providerManager
            )
        }
    }


    // MARK: - Placeholder

    private func placeholder(
        title:
            String,
        systemImage:
            String,
        description:
            String
    ) -> some View {

        ContentUnavailableView(
            title,
            systemImage:
                systemImage,
            description:
                Text(
                    description
                )
        )
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }
}


// MARK: - Preview

#Preview {

    MainContentView(
        scene:
            SceneModel(
                application:
                    ApplicationModel()
            )
    )
    .frame(
        width:
            1100,
        height:
            760
    )
}
