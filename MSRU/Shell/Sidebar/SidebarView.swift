//
//  SidebarView.swift
//  MSRU
//

import SwiftUI


struct SidebarView: View {

    @Binding var selection:
        SidebarSection?


    var body: some View {

        List(
            selection:
                $selection
        ) {

            Section(
                "Discover"
            ) {

                ForEach(
                    SidebarSection
                        .discoverSections
                ) { section in

                    Label(
                        section.title,
                        systemImage:
                            section.systemImage
                    )
                    .tag(section)
                }
            }


            Section(
                "Library"
            ) {

                ForEach(
                    SidebarSection
                        .librarySections
                ) { section in

                    Label(
                        section.title,
                        systemImage:
                            section.systemImage
                    )
                    .tag(section)
                }
            }
        }
        .listStyle(
            .sidebar
        )
    }
}


#Preview {
    SidebarView(
        selection:
            .constant(
                .listenNow
            )
    )
    .frame(
        width: 220,
        height: 600
    )
}
