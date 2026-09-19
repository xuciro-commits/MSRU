//
//  AccessoryPreviewHost.swift
//  AppFoundationUI
//

import SwiftUI


// MARK: - Accessory Preview Host

/// Lightweight diagnostic renderer for accessory presentations.
///
/// Production placement is intentionally left to the platform shell.
@MainActor
public struct AccessoryPreviewHost<Context>:
    View {

    private let presentation:
        AccessoryPresentation<Context>

    private let context:
        Context


    public init(
        presentation: AccessoryPresentation<Context>,
        context: Context
    ) {
        self.presentation =
            presentation

        self.context =
            context
    }


    public var body:
        some View {

        HStack(
            spacing: 12
        ) {

            Text(
                scopeTitle
            )
            .font(
                .caption.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                .secondary
            )


            Divider()
                .frame(
                    height:
                        24
                )


            presentation
                .content(
                    for:
                        context
                )
                .frame(
                    maxWidth:
                        .infinity
                )
        }
        .padding(
            .horizontal,
            12
        )
        .padding(
            .vertical,
            8
        )
    }


    private var scopeTitle:
        String {

        switch presentation.scope {

        case .application:
            "Application"

        case .workspace:
            "Workspace"
        }
    }
}


// MARK: - Preview

private struct AccessoryPreviewFixture {

    let title:
        String
}


#Preview("Accessory · Application") {

    let fixture =
        AccessoryPreviewFixture(
            title:
                "Now Playing"
        )


    let presentation =
        AccessoryPresentation<
            AccessoryPreviewFixture
        >(
            id:
                "playback",
            scope:
                .application
        ) {
            context in

            HStack {

                Image(
                    systemName:
                        "music.note"
                )

                Text(
                    context.title
                )

                Spacer()

                Button(
                    "Previous",
                    systemImage:
                        "backward.fill"
                ) {}

                Button(
                    "Play",
                    systemImage:
                        "play.fill"
                ) {}

                Button(
                    "Next",
                    systemImage:
                        "forward.fill"
                ) {}
            }
            .buttonStyle(
                .plain
            )
        }


    AccessoryPreviewHost(
        presentation:
            presentation,
        context:
            fixture
    )
    .frame(
        width:
            720
    )
}
