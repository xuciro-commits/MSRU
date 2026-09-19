//
//  WorkspaceContentView.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Workspace Content View

/// Renders only the primary content surface of a workspace.
///
/// This view deliberately ignores:
/// - context
/// - accessories
/// - navigation
/// - toolbar contributions
///
/// Those belong to the application shell.
///
/// Keeping this renderer small lets existing applications adopt
/// `WorkspacePresentation` without changing their visual hierarchy.
@MainActor
public struct WorkspaceContentView<Context>:
    View {

    private let presentation:
        WorkspacePresentation<Context>

    private let context:
        Context


    public init(
        presentation: WorkspacePresentation<Context>,
        context: Context
    ) {

        self.presentation =
            presentation

        self.context =
            context
    }


    public var body:
        some View {

        presentation
            .content(
                for:
                    context
            )
    }
}


// MARK: - Preview

private struct WorkspaceContentPreviewContext {

    let title:
        String
}


#Preview("Workspace Content") {

    let context =
        WorkspaceContentPreviewContext(
            title:
                "Primary Workspace"
        )


    let presentation =
        WorkspacePresentation<
            WorkspaceContentPreviewContext
        >(
            identity:
                WorkspaceIdentity(
                    title:
                        "Preview Workspace"
                )
        ) {
            context in

            VStack(
                spacing:
                    12
            ) {

                Image(
                    systemName:
                        "rectangle.center.inset.filled"
                )
                .font(
                    .largeTitle
                )
                .foregroundStyle(
                    .secondary
                )


                Text(
                    context.title
                )
                .font(
                    .title2.weight(
                        .semibold
                    )
                )


                Text(
                    "Only the primary workspace surface is rendered here."
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
        }


    WorkspaceContentView(
        presentation:
            presentation,
        context:
            context
    )
    .frame(
        width:
            720,
        height:
            460
    )
}
