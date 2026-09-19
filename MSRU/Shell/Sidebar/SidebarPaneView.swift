//
//  SidebarPaneView.swift
//  MSRU
//

import SwiftUI
import Observation


struct SidebarPaneView:
    View {

    @Bindable
    var scene:
        SceneModel


    var body:
        some View {

        SidebarView(
            selection:
                sidebarSelection
        )
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }


    // MARK: - SwiftUI Adapter

    private var sidebarSelection:
        Binding<SceneSection?> {

        Binding(
            get: {

                scene
                    .navigation
                    .section
            },
            set: {
                section in

                guard
                    let section
                else {

                    return
                }


                scene
                    .send(
                        .navigate(
                            .section(
                                section
                            )
                        )
                    )
            }
        )
    }
}
