//
//  SidebarView.swift
//  MSRU
//

import SwiftUI


struct SidebarView:
    View {

    @Binding
    var selection:
        SceneSection?


    var body:
        some View {

        List(
            selection:
                $selection
        ) {

            Section(
                "Discover"
            ) {

                ForEach(
                    SceneSection
                        .discoverSections
                ) {
                    section in

                    Label(
                        section.title,
                        systemImage:
                            section.systemImage
                    )
                    .tag(
                        section
                    )
                }
            }


            Section(
                "Library"
            ) {

                ForEach(
                    SceneSection
                        .librarySections
                ) {
                    section in

                    Label(
                        section.title,
                        systemImage:
                            section.systemImage
                    )
                    .tag(
                        section
                    )
                }
            }
        }
        .listStyle(
            .sidebar
        )
    }
}


// MARK: - Preview

#Preview {

    SidebarView(
        selection:
            .constant(
                .listenNow
            )
    )
    .frame(
        width:
            220,
        height:
            600
    )
}
