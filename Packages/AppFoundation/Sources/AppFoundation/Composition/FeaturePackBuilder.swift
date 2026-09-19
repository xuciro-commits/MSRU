//
//  FeaturePackBuilder.swift
//  AppFoundation
//


// MARK: - Feature Pack Builder

public struct FeaturePackBuilder<Route>
where
    Route:
        Hashable & Sendable {

    private var pack:
        FeaturePack<Route>


    public init() {

        self.pack =
            FeaturePack()
    }


    @discardableResult
    public mutating func add<F>(
        _ feature:
            F.Type
    ) -> Self
    where
        F:
            ApplicationFeature,
        F.Route == Route {

        pack.append(
            F.contributions
        )

        return self
    }


    public func build()
        -> FeaturePack<Route> {

        var result =
            pack

        result.normalize()

        return result
    }
}
