//
//  SidebarView.swift
//  MSRU
//

import SwiftUI
import AppFoundation
import AppFoundationUI


struct SidebarView:
    View {

    @Binding
    var selection:
        SceneRoute?


    let contributions:
        [SidebarContribution<SceneRoute>]


    var body:
        some View {

        ApplicationSidebar(
            selection:
                $selection,
            contributions:
                contributions
        )
    }
}


// MARK: - Preview

#Preview {

    SidebarView(
        selection:
            .constant(
                .section(
                    .listenNow
                )
            ),
        contributions:
            MSRUApplication.definition.sidebar
    )
    .frame(
        width:
            220,
        height:
            600
    )
}
