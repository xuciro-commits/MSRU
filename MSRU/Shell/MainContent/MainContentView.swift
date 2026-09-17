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
                .backgroundExtensionEffect()


            page
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }


    // MARK: - Platform Background

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

            placeholder(
                title:
                    "Browse",
                systemImage:
                    "sparkles",
                description:
                    "Browse music content."
            )


        case .radio:

            placeholder(
                title:
                    "Radio",
                systemImage:
                    "dot.radiowaves.left.and.right",
                description:
                    "Radio content."
            )


        case .library:

            LocalLibraryView(
                store:
                    appState.localLibrary,
                playback:
                    appState.playback,
                selectedTrack:
                    $appState.selectedLocalTrack
            )


        case .importAppleMusic:

            AppleMusicImportView(
                store:
                    appState.musicLibrary,
                onImportCompleted: {

                    appState
                        .selectedSection =
                        .library
                }
            )


        case .settings:

            placeholder(
                title:
                    "Settings",
                systemImage:
                    "gear",
                description:
                    "Application settings."
            )
        }
    }


    // MARK: - Placeholder

    private func placeholder(
        title: String,
        systemImage: String,
        description: String
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
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}


#Preview {

    MainContentView(
        appState:
            AppState()
    )
    .frame(
        width: 1000,
        height: 700
    )
}
