//
//  SidebarPaneView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundation
import AppFoundationUI


struct SidebarPaneView:
    View {

    @Bindable
    var scene:
        SceneModel


    var body:
        some View {

        SidebarView(
            selection:
                sidebarSelection,
            contributions:
                MSRUApplication.definition.sidebar
        )
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }


    // MARK: - Scene Routing Adapter

    private var sidebarSelection:
        Binding<SceneRoute?> {

        Binding(
            get: {

                .section(
                    scene
                        .navigation
                        .section
                )
            },
            set: {
                route in

                guard
                    let route
                else {

                    return
                }


                scene
                    .send(
                        .navigate(
                            route
                        )
                    )
            }
        )
    }
}

#Preview("Scene Navigation") {
    SidebarPaneView(scene: MSRUPreviewData.makeScene()).frame(width: 240, height: 600)
}
