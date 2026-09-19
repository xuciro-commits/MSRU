//
//  ApplicationFeaturePresentation.swift
//  AppFoundationUI
//

import AppFoundation


public protocol ApplicationFeaturePresentation:
    ApplicationFeature {

    associatedtype PresentationContext


    @MainActor
    static var routeDestinations:
        [
            RouteDestination<
                Route,
                PresentationContext
            >
        ] {
        get
    }
}
