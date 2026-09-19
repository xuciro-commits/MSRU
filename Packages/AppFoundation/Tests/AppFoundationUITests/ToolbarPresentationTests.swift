//
//  ToolbarPresentationTests.swift
//  AppFoundationUITests
//

import Testing

@testable import AppFoundationUI


@MainActor
private final class ToolbarTestModel {

    var query:
        String

    var actionCount =
        0


    init(
        query:
            String = ""
    ) {

        self.query =
            query
    }
}


struct ToolbarPresentationTests {

    @Test
    @MainActor
    func actionResolvesAgainstContext() {

        let model =
            ToolbarTestModel()


        let toolbar =
            ToolbarPresentation<
                ToolbarTestModel
            >(
                items:
                    [
                        .action(
                            ToolbarActionPresentation(
                                id:
                                    "run",
                                title:
                                    "Run",
                                systemImage:
                                    "play.fill",
                                perform: {
                                    model in

                                    model
                                        .actionCount +=
                                            1
                                }
                            )
                        )
                    ]
            )


        let resolved =
            toolbar.resolved(
                for:
                    model
            )


        guard
            case .action(
                let action
            ) =
                resolved.items.first
        else {

            Issue.record(
                "Expected resolved toolbar action."
            )

            return
        }


        action.perform()


        #expect(
            model.actionCount
            ==
            1
        )
    }


    @Test
    @MainActor
    func searchResolvesStateAndAction() {

        let model =
            ToolbarTestModel(
                query:
                    "initial"
            )


        let toolbar =
            ToolbarPresentation<
                ToolbarTestModel
            >(
                items:
                    [
                        .search(
                            ToolbarSearchPresentation(
                                id:
                                    "search",
                                prompt:
                                    "Search",
                                text: {
                                    model in

                                    model.query
                                },
                                update: {
                                    model,
                                    value in

                                    model.query =
                                        value
                                }
                            )
                        )
                    ]
            )


        let resolved =
            toolbar.resolved(
                for:
                    model
            )


        guard
            case .search(
                let search
            ) =
                resolved.items.first
        else {

            Issue.record(
                "Expected resolved toolbar search."
            )

            return
        }


        #expect(
            search.text
            ==
            "initial"
        )


        search.update(
            "updated"
        )


        #expect(
            model.query
            ==
            "updated"
        )
    }


    @Test
    @MainActor
    func resolvedPresentationsMergeAcrossDifferentContexts() {

        let first =
            ResolvedToolbarPresentation(
                items:
                    []
            )

        let second =
            ResolvedToolbarPresentation(
                items:
                    []
            )


        let merged =
            first.merging(
                second
            )


        #expect(
            merged.items.isEmpty
        )
    }
}
