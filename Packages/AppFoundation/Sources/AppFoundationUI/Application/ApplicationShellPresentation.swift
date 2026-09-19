//
//  ApplicationShellPresentation.swift
//  AppFoundationUI
//

// MARK: - Application Shell Presentation

/// Describes application-level supporting presentation surfaces.
///
/// `ApplicationShellPresentation` is semantic composition only.
/// It does not prescribe where or how these surfaces are rendered.
@MainActor
public struct ApplicationShellPresentation<Context> {

    public let contexts:
        [ContextPresentation<Context>]

    public let accessories:
        [AccessoryPresentation<Context>]

    public let toolbar:
        ToolbarPresentation<Context>


    public init(
        contexts:
            [ContextPresentation<Context>] = [],
        accessories:
            [AccessoryPresentation<Context>] = [],
        toolbar:
            ToolbarPresentation<Context> = .init()
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

        self.toolbar =
            toolbar
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
