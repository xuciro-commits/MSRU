//
//  WorkspacePreviewHost.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Workspace Preview Host

/// An isolated development surface for `WorkspacePresentation`.
///
/// It intentionally visualizes semantic regions without making decisions
/// about the final macOS or iPadOS shell implementation.
@MainActor
public struct WorkspacePreviewHost<Context>:
    View {

    private let presentation:
        WorkspacePresentation<Context>

    private let context:
        Context

    private let contextWidth:
        CGFloat


    public init(
        presentation: WorkspacePresentation<Context>,
        context: Context,
        contextWidth: CGFloat = 280
    ) {
        self.presentation =
            presentation

        self.context =
            context

        self.contextWidth =
            contextWidth
    }


    public var body:
        some View {

        VStack(
            spacing:
                0
        ) {

            identityRegion


            Divider()


            HStack(
                spacing:
                    0
            ) {

                presentation
                    .content(
                        for:
                            context
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        maxHeight:
                            .infinity
                    )


                if let contextualPresentation =
                    presentation.context {

                    Divider()


                    ContextPreviewHost(
                        presentation:
                            contextualPresentation,
                        context:
                            context
                    )
                    .frame(
                        width:
                            contextWidth
                    )
                }
            }


            if let accessory =
                presentation.workspaceAccessory {

                Divider()


                AccessoryPreviewHost(
                    presentation:
                        accessory,
                    context:
                        context
                )
            }
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }


    @ViewBuilder
    private var identityRegion:
        some View {

        if let identity =
            presentation.identity {

            HStack(
                spacing:
                    10
            ) {

                if let systemImage =
                    identity.systemImage {

                    Image(
                        systemName:
                            systemImage
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {

                    Text(
                        identity.title
                    )
                    .font(
                        .headline
                    )


                    if let subtitle =
                        identity.subtitle {

                        Text(
                            subtitle
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }


                Spacer()


                Text(
                    "Preview Host"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .tertiary
                )
            }
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                10
            )

        } else {

            EmptyView()
        }
    }
}


// MARK: - Preview

private struct WorkspacePreviewFixture {

    let tracks:
        [String]

    let selectedTrack:
        String?
}


#Preview("Workspace · Library") {

    let fixture =
        WorkspacePreviewFixture(
            tracks: [
                "Northern Lights",
                "Arc",
                "Signal",
                "Afterglow"
            ],
            selectedTrack:
                "Northern Lights"
        )


    let context =
        ContextPresentation<
            WorkspacePreviewFixture
        >(
            id:
                "track-preview",
            role:
                .preview
        ) {
            context in

            VStack(
                alignment:
                    .leading,
                spacing:
                    10
            ) {

                Text(
                    context.selectedTrack
                    ??
                    "No Selection"
                )
                .font(
                    .title3
                )

                Text(
                    "Selection metadata appears here."
                )
                .foregroundStyle(
                    .secondary
                )

                Spacer()
            }
            .padding()
        }


    let accessory =
        AccessoryPresentation<
            WorkspacePreviewFixture
        >(
            id:
                "selection-summary",
            scope:
                .workspace
        ) {
            context in

            HStack {

                Text(
                    "\(context.tracks.count) tracks"
                )

                Spacer()

                Text(
                    context.selectedTrack
                    ??
                    "No selection"
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }


    let presentation =
        WorkspacePresentation<
            WorkspacePreviewFixture
        >(
            identity:
                WorkspaceIdentity(
                    title:
                        "Library",
                    subtitle:
                        "\(fixture.tracks.count) tracks",
                    systemImage:
                        "music.note.list"
                ),
            context:
                context,
            workspaceAccessory:
                accessory
        ) {
            context in

            List(
                context.tracks,
                id:
                    \.self
            ) {
                track in

                Label(
                    track,
                    systemImage:
                        "music.note"
                )
            }
        }


    WorkspacePreviewHost(
        presentation:
            presentation,
        context:
            fixture
    )
    .frame(
        width:
            900,
        height:
            560
    )
}
