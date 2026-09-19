//
//  MacApplicationSplitPreviewHost.swift
//  AppFoundationUI
//

#if os(macOS)

import SwiftUI


// MARK: - Preview Host

private struct MacApplicationSplitPreviewRepresentable:
    NSViewControllerRepresentable {

    func makeNSViewController(
        context:
            Context
    ) -> MacApplicationSplitController {

        let navigation =
            MacHostingControllerFactory
                .make(
                    rootView:
                        List {
                            Text(
                                "Home"
                            )

                            Text(
                                "Projects"
                            )

                            Text(
                                "Library"
                            )
                        }
                )


        let workspace =
            MacHostingControllerFactory
                .make(
                    rootView:
                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                12
                        ) {

                            Text(
                                "Workspace"
                            )
                            .font(
                                .largeTitle
                            )


                            Text(
                                "Primary working surface"
                            )
                            .foregroundStyle(
                                .secondary
                            )


                            Spacer()
                        }
                        .frame(
                            maxWidth:
                                .infinity,
                            maxHeight:
                                .infinity,
                            alignment:
                                .topLeading
                        )
                        .padding(
                            28
                        )
                )


        let controller =
            MacApplicationSplitController(
                navigationViewController:
                    navigation,
                workspaceViewController:
                    workspace,
                configuration:
                    .init(
                        backgroundColor:
                            .windowBackgroundColor,
                        navigation:
                            .init(
                                canCollapse:
                                    true,
                                allowsFullHeightLayout:
                                    true,
                                minimumThickness:
                                    180,
                                maximumThickness:
                                    280
                            ),
                        workspace:
                            .init(
                                canCollapse:
                                    false,
                                minimumThickness:
                                    480
                            )
                    )
            )


        let contextController =
            MacHostingControllerFactory
                .make(
                    rootView:
                        VStack(
                            alignment:
                                .leading
                        ) {

                            Text(
                                "Context"
                            )
                            .font(
                                .headline
                            )


                            Text(
                                "Inspector / Preview / Activity / Utility"
                            )
                            .foregroundStyle(
                                .secondary
                            )


                            Spacer()
                        }
                        .frame(
                            maxWidth:
                                .infinity,
                            maxHeight:
                                .infinity,
                            alignment:
                                .topLeading
                        )
                        .padding()
                )


        controller.installContext(
            viewController:
                contextController,
            configuration:
                .init(
                    canCollapse:
                        true,
                    allowsFullHeightLayout:
                        true,
                    minimumThickness:
                        260,
                    maximumThickness:
                        420
                )
        )


        return
            controller
    }


    func updateNSViewController(
        _ nsViewController:
            MacApplicationSplitController,
        context:
            Context
    ) {}
}


#Preview(
    "macOS Application Split Shell"
) {

    MacApplicationSplitPreviewRepresentable()
        .frame(
            width:
                1100,
            height:
                700
        )
}

#endif
