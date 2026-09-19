//
//  ApplicationRouteView.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Application Route View

/// Compatibility renderer from application routing into workspace content.
///
/// Route resolution now produces a `WorkspacePresentation`.
///
/// This view intentionally renders only the workspace's primary surface.
/// Full shell presentation is the responsibility of the future platform shell.
@MainActor
public struct ApplicationRouteView<
    Route,
    Context,
    Fallback
>:
    View
where
    Route:
        Hashable & Sendable,
    Fallback:
        View {

    private let route:
        Route

    private let context:
        Context

    private let destinations:
        [RouteDestination<Route, Context>]

    private let fallback:
        (Route) -> Fallback


    public init(
        route: Route,
        context: Context,
        destinations: [RouteDestination<Route, Context>],
        @ViewBuilder fallback: @escaping (Route) -> Fallback
    ) {

        self.route =
            route

        self.context =
            context

        self.destinations =
            destinations

        self.fallback =
            fallback
    }


    public var body:
        some View {

        if let destination =
            destination {

            WorkspaceContentView(
                presentation:
                    destination
                        .workspace(
                            for:
                                route,
                            context:
                                context
                        ),
                context:
                    context
            )

        } else {

            fallback(
                route
            )
        }
    }


    private var destination:
        RouteDestination<Route, Context>? {

        destinations
            .first {
                $0.matches(
                    route
                )
            }
    }
}


// MARK: - Preview

private enum ApplicationRoutePreviewRoute:
    Hashable,
    Sendable {

    case library
    case missing
}


private struct ApplicationRoutePreviewContext {

    let count:
        Int
}


#Preview("Application Route · Workspace") {

    let destination =
        RouteDestination<
            ApplicationRoutePreviewRoute,
            ApplicationRoutePreviewContext
        >(
            id:
                "library",
            route:
                .library,
            workspace: {
                context in

                WorkspacePresentation(
                    identity:
                        WorkspaceIdentity(
                            title:
                                "Library",
                            subtitle:
                                "\(context.count) items"
                        )
                ) {
                    _ in

                    List(
                        0..<context.count,
                        id:
                            \.self
                    ) {
                        index in

                        Text(
                            "Item \(index + 1)"
                        )
                    }
                }
            }
        )


    ApplicationRouteView(
        route:
            .library,
        context:
            ApplicationRoutePreviewContext(
                count:
                    6
            ),
        destinations:
            [
                destination
            ]
    ) {
        _ in

        VStack(
            spacing:
                12
        ) {

            Image(
                systemName:
                    "questionmark"
            )
            .font(
                .largeTitle
            )
            .foregroundStyle(
                .secondary
            )


            Text(
                "Unsupported Route"
            )
            .font(
                .headline
            )
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }
    .frame(
        width:
            720,
        height:
            460
    )
}
