//
//  ContextPresentation.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Context Presentation

/// A semantic contextual surface associated with a workspace.
///
/// Examples:
/// - an inspector for the current selection
/// - a Finder-like preview
/// - a playback queue
/// - a utility surface
///
/// Type erasure is intentionally contained at this presentation boundary.
@MainActor
public struct ContextPresentation<Context> {

    public let id: String
    public let role: ContextRole

    private let buildContent:
        (Context) -> AnyView


    public init<Content: View>(
        id: String,
        role: ContextRole,
        @ViewBuilder content: @escaping (Context) -> Content
    ) {
        self.id = id
        self.role = role
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
