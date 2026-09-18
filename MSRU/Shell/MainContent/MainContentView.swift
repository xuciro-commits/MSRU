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


struct MainContentView: View {

    @Bindable var appState:
        AppState


    var body: some View {

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
            appState.selectedSection
            ?? .listenNow {

        case .listenNow:

            ListenNowView(
                store:
                    appState.musicCatalog,
                onSelect: {
                    item in

                    appState
                        .selectedMusicContent =
                        item
                }
            )


        case .browse:

            BrowseView(
                feature:
                    appState.browse
            )


        case .radio:

            placeholder(
                title:
                    "Radio",
                systemImage:
                    "dot.radiowaves.left.and.right",
                description:
                    "Radio providers and continuous playback will land in a later milestone."
            )


        case .library:

            LibraryView(
                library:
                    appState.library,
                localStore:
                    appState.localLibrary,
                playback:
                    appState.playback,
                selectedLocalTrack:
                    $appState.selectedLocalTrack,
                onAddMusic: {

                    appState
                        .selectedSection =
                        .addMusic
                }
            )


        case .addMusic:

            AddMusicView(
                localStore:
                    appState.localLibrary,
                appleMusicStore:
                    appState.musicLibrary,
                onOpenLibrary: {

                    appState
                        .selectedSection =
                        .library
                }
            )


        case .settings:

            SettingsView(
                playback:
                    appState.playback,
                providerManager:
                    appState.providerManager
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


#Preview {

    MainContentView(
        appState:
            AppState()
    )
    .frame(
        width: 1100,
        height: 760
    )
}
