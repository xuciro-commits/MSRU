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

        let sorted =
            contributions
                .sorted {

                    if $0.group
                        == $1.group {

                        return $0.order
                            < $1.order
                    }

                    return ($0.group ?? "")
                        < ($1.group ?? "")
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

            Label {

                Text(
                    item.title
                )

            } icon: {

                Image(
                    systemName:
                        item.systemImage
                )
            }
            .tag(
                item.route
            )
        }
    }
}
