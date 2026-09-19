//
//  FeaturePresentationPackBuilder.swift
//  AppFoundationUI
//

import AppFoundation


@MainActor
public struct FeaturePresentationPackBuilder<Route, Context>
where
    Route: Hashable & Sendable {

    private var pack:
        FeaturePresentationPack<Route, Context>


    public init() {

        self.pack =
            FeaturePresentationPack()
    }


    @discardableResult
    public mutating func add<F>(
        _ feature:
            F.Type
    ) -> Self
    where
        F: ApplicationFeaturePresentation,
        F.Route == Route,
        F.PresentationContext == Context {

        pack.append(
            contentsOf:
                F.routeDestinations
        )

        return self
    }


    public func build()
        -> FeaturePresentationPack<Route, Context> {

        pack
    }
}
