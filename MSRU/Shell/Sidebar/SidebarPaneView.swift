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
                $scene
                    .selectedSection
        )
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }
}
