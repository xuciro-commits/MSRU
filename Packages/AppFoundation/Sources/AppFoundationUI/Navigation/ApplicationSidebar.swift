//
//  ApplicationSidebar.swift
//  AppFoundationUI
//

import SwiftUI
import AppFoundation


// MARK: - Render Group

private struct SidebarRenderGroup<Route>:
    Identifiable
where
    Route:
        Hashable & Sendable {

    let id:
        String

    let title:
        String?

    var items:
        [SidebarContribution<Route>]
}

#Preview("Application Sidebar") {
    @Previewable @State var selection: String? = "library"
    ApplicationSidebar(
        selection: $selection,
        contributions: [
            SidebarContribution(id: "browse", title: "Browse", systemImage: "globe", route: "browse"),
            SidebarContribution(id: "library", group: "Collection", title: "Library", systemImage: "books.vertical", route: "library")
        ]
    )
    .frame(width: 240, height: 400)
}


// MARK: - Application Sidebar

/*
 ApplicationSidebar 只负责：

 SidebarContribution<Route>
        ↓
 SwiftUI List / Section / Label


 它不拥有 Application structure。

 Structure 来自 AppFoundation FeaturePack。
 */

public struct ApplicationSidebar<Route>:
    View
where
    Route:
        Hashable & Sendable {

    // MARK: - Selection

    @Binding
    private var selection:
        Route?


    // MARK: - Contributions

    private let contributions:
        [SidebarContribution<Route>]


    // MARK: - Init

    public init(
        selection:
            Binding<Route?>,
        contributions:
            [SidebarContribution<Route>]
    ) {

        self._selection =
            selection

        self.contributions =
            contributions
    }


    // MARK: - Body

    public var body:
        some View {

        List(
            selection:
                $selection
        ) {

            ForEach(
                groups
            ) {
                group in

                if let title =
                    group.title {

                    Section {

                        rows(
                            group.items
                        )

                    } header: {

                        Text(
                            title
                        )
                    }

                } else {

                    Section {

                        rows(
                            group.items
                        )
                    }
                }
            }
        }
        .listStyle(
            .sidebar
        )
    }


    // MARK: - Groups

    private var groups:
        [SidebarRenderGroup<Route>] {

        var groupOrders: [String: Int] = [:]
        for item in contributions {
            let gid = item.group ?? ""
            let currentMin = groupOrders[gid] ?? Int.max
            groupOrders[gid] = min(currentMin, item.order)
        }

        let sorted =
            contributions
                .sorted { a, b in
                    let aGroup = a.group ?? ""
                    let bGroup = b.group ?? ""
                    if aGroup == bGroup {
                        return a.order < b.order
                    }
                    let aGroupOrder = groupOrders[aGroup] ?? 0
                    let bGroupOrder = groupOrders[bGroup] ?? 0
                    if aGroupOrder != bGroupOrder {
                        return aGroupOrder < bGroupOrder
                    }
                    return aGroup < bGroup
                }


        var result:
            [SidebarRenderGroup<Route>] = []


        for item in sorted {

            let id =
                item.group
                ?? "__ungrouped"


            if let index =
                result.firstIndex(
                    where: {
                        $0.id == id
                    }
                ) {

                result[index]
                    .items
                    .append(
                        item
                    )

            } else {

                result.append(
                    SidebarRenderGroup(
                        id:
                            id,
                        title:
                            item.group,
                        items: [
                            item
                        ]
                    )
                )
            }
        }


        return result
    }


    // MARK: - Rows

    @ViewBuilder
    private func rows(
        _ items:
            [SidebarContribution<Route>]
    ) -> some View {

        ForEach(
            items
        ) {
            item in

            HStack {
                Label {
                    Text(item.title)
                } icon: {
                    Image(systemName: item.systemImage)
                }

                if let badge = item.badge {
                    Spacer()
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            .tag(
                item.route
            )
        }
    }
}
