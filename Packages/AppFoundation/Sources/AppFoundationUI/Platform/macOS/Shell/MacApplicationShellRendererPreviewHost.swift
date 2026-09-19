//
//  MacApplicationShellRendererPreviewHost.swift
//  AppFoundationUI
//

#if os(macOS)

import SwiftUI


private struct RendererPreviewContext {

    let title:
        String
}


private struct MacApplicationShellRendererRepresentable:
    NSViewControllerRepresentable {

    func makeNSViewController(
        context:
            Context
    ) -> MacApplicationSplitController {

        let value =
            RendererPreviewContext(
                title:
                    "Preview Workspace"
            )


        let workspace =
            WorkspacePresentation<
                RendererPreviewContext
            >(
                identity:
                    .init(
                        title:
                            "Preview Workspace"
                    ),
                context:
                    ContextPresentation(
                        id:
                            "preview.context",
                        role:
                            .preview
                    ) {
                        value in

                        Text(
                            "Context for \(value.title)"
                        )
                        .padding()
                    },
                workspaceAccessory:
                    AccessoryPresentation(
                        id:
                            "preview.workspace-accessory",
                        scope:
                            .workspace
                    ) {
                        _ in

                        Text(
                            "Workspace Accessory"
                        )
                        .padding(
                            8
                        )
                    }
            ) {
                value in

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        12
                ) {

                    Text(
                        value.title
                    )
                    .font(
                        .largeTitle
                    )


                    Text(
                        "Resolved by ApplicationShellRuntime"
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
                    30
                )
            }


        let resolvedWorkspace =
            ResolvedWorkspacePresentation(
                presentation:
                    workspace,
                context:
                    value
            )


        let applicationContext =
            ResolvedContextPresentation(
                presentation:
                    ContextPresentation(
                        id:
                            "preview.activity",
                        role:
                            .activity
                    ) {
                        _ in

                        Text(
                            "Application Activity"
                        )
                        .padding()
                    },
                context:
                    value
            )


        let applicationAccessory =
            ResolvedAccessoryPresentation(
                presentation:
                    AccessoryPresentation(
                        id:
                            "preview.application-accessory",
                        scope:
                            .application
                    ) {
                        _ in

                        Text(
                            "Application Accessory"
                        )
                        .padding(
                            8
                        )
                    },
                context:
                    value
            )


        let shell =
            ResolvedApplicationShell(
                workspace:
                    resolvedWorkspace,
                applicationContexts:
                    [
                        applicationContext
                    ],
                applicationAccessories:
                    [
                        applicationAccessory
                    ],
                toolbar:
                    ResolvedToolbarPresentation()
            )


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


        let renderer =
            MacApplicationShellRenderer(
                navigationViewController:
                    navigation,
                shell:
                    shell,
                configuration:
                    .init(
                        split:
                            .init(
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
                                            500
                                    )
                            ),
                        context:
                            .init(
                                region:
                                    .init(
                                        canCollapse:
                                            true,
                                        allowsFullHeightLayout:
                                            true,
                                        minimumThickness:
                                            260,
                                        maximumThickness:
                                            400
                                    ),
                                resolve: {
                                    shell in

                                    shell
                                        .workspace?
                                        .context
                                }
                            ),
                        applicationAccessory:
                            .init(
                                resolve: {
                                    shell in

                                    shell
                                        .applicationAccessories
                                        .first
                                }
                            )
                    )
            )


        return
            renderer
                .splitController
    }


    func updateNSViewController(
        _ nsViewController:
            MacApplicationSplitController,
        context:
            Context
    ) {}
}


#Preview(
    "Resolved Application Shell"
) {

    MacApplicationShellRendererRepresentable()
        .frame(
            width:
                1200,
            height:
                720
        )
}

#endif
