//
//  MainContentView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundationUI


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


    // MARK: - Body

    var body:
        some View {

        ZStack {

            platformBackground
                .ignoresSafeArea()


            ApplicationRouteView(
                route:
                    scene
                        .navigation
                        .route,
                context:
                    scene,
                destinations:
                    MSRUApplication.definition.routeDestinations
            ) {
                _ in

                unsupportedDestination
            }
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


    // MARK: - Unsupported Destination

    private var unsupportedDestination:
        some View {

        ContentUnavailableView(
            "Destination Unavailable",
            systemImage:
                "questionmark.square.dashed",
            description:
                Text(
                    "No presentation is registered for this route."
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
