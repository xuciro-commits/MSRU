//
//  ApplicationShellPresentationTests.swift
//  AppFoundationUITests
//

import SwiftUI
import Testing

@testable import AppFoundationUI


private struct ShellPresentationTestContext {

    let title:
        String
}


struct ApplicationShellPresentationTests {

    @Test
    @MainActor
    func resolvesContextByIdentifier() {

        let activity =
            ContextPresentation<
                ShellPresentationTestContext
            >(
                id:
                    "activity",
                role:
                    .activity
            ) {
                context in

                Text(
                    context.title
                )
            }


        let presentation =
            ApplicationShellPresentation(
                contexts:
                    [
                        activity
                    ]
            )


        #expect(
            presentation
                .context(
                    id:
                        "activity"
                )?
                .role
            ==
            .activity
        )
    }


    @Test
    @MainActor
    func resolvesApplicationAccessoryByIdentifier() {

        let accessory =
            AccessoryPresentation<
                ShellPresentationTestContext
            >(
                id:
                    "player",
                scope:
                    .application
            ) {
                context in

                Text(
                    context.title
                )
            }


        let presentation =
            ApplicationShellPresentation(
                accessories:
                    [
                        accessory
                    ]
            )


        #expect(
            presentation
                .accessory(
                    id:
                        "player"
                )?
                .scope
            ==
            .application
        )
    }


    @Test
    @MainActor
    func filtersContextsBySemanticRole() {

        let inspector =
            ContextPresentation<
                ShellPresentationTestContext
            >(
                id:
                    "inspector",
                role:
                    .inspector
            ) {
                _ in

                Text(
                    "Inspector"
                )
            }


        let activity =
            ContextPresentation<
                ShellPresentationTestContext
            >(
                id:
                    "activity",
                role:
                    .activity
            ) {
                _ in

                Text(
                    "Activity"
                )
            }


        let presentation =
            ApplicationShellPresentation(
                contexts:
                    [
                        inspector,
                        activity
                    ]
            )


        let activities =
            presentation
                .contexts(
                    role:
                        .activity
                )


        #expect(
            activities.count
            ==
            1
        )

        #expect(
            activities.first?.id
            ==
            "activity"
        )
    }
}
