//
//  AccessoryPresentation.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Accessory Presentation

/// A persistent supporting surface that is not the primary command surface.
///
/// Examples:
/// - application-scoped playback controls
/// - workspace-scoped timeline controls
/// - sync or transfer status
///
/// Type erasure is intentionally contained at this presentation boundary.
@MainActor
public struct AccessoryPresentation<Context> {

    public let id: String
    public let scope: AccessoryScope

    private let buildContent:
        (Context) -> AnyView


    public init<Content: View>(
        id: String,
        scope: AccessoryScope,
        @ViewBuilder content: @escaping (Context) -> Content
    ) {
        self.id = id
        self.scope = scope
        self.buildContent = {
            context in

            AnyView(
                content(context)
            )
        }
    }


    public func content(
        for context: Context
    ) -> AnyView {

        buildContent(
            context
        )
    }
}
