//
//  ApplicationShellPresentation.swift
//  AppFoundationUI
//

// MARK: - Application Shell Presentation

/// Describes application-level supporting presentation surfaces.
///
/// `ApplicationShellPresentation` is semantic composition only.
/// It does not prescribe where or how these surfaces are rendered.
///
/// A platform shell may present contexts using:
///
/// - a split item
/// - an inspector
/// - a sheet
/// - a popover
/// - an overlay
///
/// Application accessories may similarly be hosted using the
/// native mechanism most appropriate for the platform.
///
/// This type deliberately does not contain navigation, toolbar,
/// window, AppKit, or UIKit behavior.
@MainActor
public struct ApplicationShellPresentation<Context> {

    public let contexts:
        [ContextPresentation<Context>]

    public let accessories:
        [AccessoryPresentation<Context>]


    public init(
        contexts:
            [ContextPresentation<Context>] = [],
        accessories:
            [AccessoryPresentation<Context>] = []
    ) {

        precondition(
            accessories
                .allSatisfy {
                    $0.scope
                    ==
                    .application
                },
            """
            ApplicationShellPresentation may only contain
            application-scoped accessories.
            """
        )


        self.contexts =
            contexts

        self.accessories =
            accessories
    }


    // MARK: - Resolution

    public func context(
        id:
            String
    ) -> ContextPresentation<Context>? {

        contexts
            .first {
                $0.id
                ==
                id
            }
    }


    public func accessory(
        id:
            String
    ) -> AccessoryPresentation<Context>? {

        accessories
            .first {
                $0.id
                ==
                id
            }
    }


    // MARK: - Semantic Queries

    public func contexts(
        role:
            ContextRole
    ) -> [ContextPresentation<Context>] {

        contexts
            .filter {
                $0.role
                ==
                role
            }
    }
}
