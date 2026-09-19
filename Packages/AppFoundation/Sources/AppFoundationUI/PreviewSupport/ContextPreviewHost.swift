//
//  ContextPreviewHost.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Context Preview Host

/// Lightweight diagnostic renderer for developing contextual presentations.
///
/// This is intentionally not the production shell renderer.
@MainActor
public struct ContextPreviewHost<Context>:
    View {

    private let presentation:
        ContextPresentation<Context>

    private let context:
        Context


    public init(
        presentation: ContextPresentation<Context>,
        context: Context
    ) {
        self.presentation =
            presentation

        self.context =
            context
    }


    public var body:
        some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            HStack(
                spacing: 8
            ) {

                Image(
                    systemName:
                        symbolName
                )

                Text(
                    roleTitle
                )
                .font(
                    .caption.weight(
                        .semibold
                    )
                )

                Spacer()
            }
            .foregroundStyle(
                .secondary
            )
            .padding(
                .horizontal,
                12
            )
            .padding(
                .vertical,
                10
            )


            Divider()


            presentation
                .content(
                    for:
                        context
                )
                .frame(
                    maxWidth:
                        .infinity,
                    maxHeight:
                        .infinity,
                    alignment:
                        .topLeading
                )
        }
    }


    private var roleTitle:
        String {

        switch presentation.role {

        case .inspector:
            "Inspector"

        case .preview:
            "Preview"

        case .activity:
            "Activity"

        case .utility:
            "Utility"
        }
    }


    private var symbolName:
        String {

        switch presentation.role {

        case .inspector:
            "slider.horizontal.3"

        case .preview:
            "eye"

        case .activity:
            "waveform"

        case .utility:
            "wrench.and.screwdriver"
        }
    }
}


// MARK: - Preview

private struct ContextPreviewFixture {

    let selection:
        String
}


#Preview("Context · Inspector") {

    let fixture =
        ContextPreviewFixture(
            selection:
                "Room 301"
        )


    let presentation =
        ContextPresentation<
            ContextPreviewFixture
        >(
            id:
                "room-inspector",
            role:
                .inspector
        ) {
            context in

            VStack(
                alignment:
                    .leading,
                spacing:
                    12
            ) {

                Text(
                    context.selection
                )
                .font(
                    .title2
                )

                LabeledContent(
                    "Status",
                    value:
                        "Occupied"
                )

                LabeledContent(
                    "Floor",
                    value:
                        "3"
                )

                Spacer()
            }
            .padding()
        }


    ContextPreviewHost(
        presentation:
            presentation,
        context:
            fixture
    )
    .frame(
        width:
            300,
        height:
            420
    )
}
