//
//  ApplicationDefinitionBuilder.swift
//  AppFoundationUI
//

import AppFoundation


// MARK: - Application Definition Builder

@MainActor
public struct ApplicationDefinitionBuilder<Route, Context>
where
    Route:
        Hashable & Sendable {

    private var definition:
        ApplicationDefinition<
            Route,
            Context
        >


    // MARK: - Init

    public init() {

        self.definition =
            ApplicationDefinition()
    }


    // MARK: - Feature

    /*
     一个 Feature 只注册一次。

     同时安装：

     - FeatureContribution
     - RouteDestination
     */

    @discardableResult
    public mutating func add<F>(
        _ feature:
            F.Type
    ) -> Self
    where
        F:
            ApplicationFeaturePresentation,
        F.Route == Route,
        F.PresentationContext == Context {

        definition
            .append(
                contribution:
                    F.contributions,
                routeDestinations:
                    F.routeDestinations
            )


        return self
    }


    // MARK: - Host Contribution

    /*
     Host Application 可以拥有尚未 Feature 化的能力。

     例如：

     - Listen Now
     - Radio
     - Settings

     它们也通过同一个 Definition 安装，
     而不是维护第二棵 composition tree。
     */

    @discardableResult
    public mutating func addHost(
        contribution:
            FeatureContribution<Route>,
        routeDestinations:
            [
                RouteDestination<
                    Route,
                    Context
                >
            ]
    ) -> Self {

        definition
            .append(
                contribution:
                    contribution,
                routeDestinations:
                    routeDestinations
            )


        return self
    }


    // MARK: - Build

    public func build()
        -> ApplicationDefinition<
            Route,
            Context
        > {

        var result =
            definition


        result
            .normalize()


        return result
    }
}
