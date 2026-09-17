//
//  SidebarPaneView.swift
//  MSRU
//

import SwiftUI
import Observation


struct SidebarPaneView: View {

    @Bindable var appState:
        AppState


    var body: some View {
        SidebarView(
            selection:
                $appState
                    .selectedSection
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}
