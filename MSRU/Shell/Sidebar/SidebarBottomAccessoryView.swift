//
//  SidebarBottomAccessoryView.swift
//  MSRU
//

import SwiftUI


struct SidebarBottomAccessoryView: View {

    let onToggleSidebar: () -> Void


    var body: some View {
        HStack(spacing: 10) {

            Image(
                systemName:
                    "person.crop.circle.fill"
            )
            .font(.title2)
            .foregroundStyle(.secondary)


            Text("许强")
                .font(.callout)
                .lineLimit(1)


            Spacer()


            Button {
                onToggleSidebar()
            } label: {
                Image(
                    systemName:
                        "sidebar.left"
                )
            }
            .buttonStyle(.plain)
            .help("Hide Sidebar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}


#Preview {
    SidebarBottomAccessoryView(
        onToggleSidebar: {}
    )
    .frame(width: 220)
}
