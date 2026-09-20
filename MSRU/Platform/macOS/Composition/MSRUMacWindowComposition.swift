//
//  MSRUMacWindowComposition.swift
//  MSRU
//

#if os(macOS)

import AppKit
import Observation
import SwiftUI

import AppFoundationUI


// MARK: - MSRU macOS Window Composition

/// Product/platform composition boundary for one MSRU window.
///
/// All semantic surface resolution is owned by
/// `MSRUApplicationShellSession`.
///
/// All native workspace/context/accessory rendering is owned by
/// `MacApplicationShellRenderer`.
@MainActor
final class MSRUMacWindowComposition {

    // MARK: - Scene

    private let scene:
        SceneModel


    // MARK: - Semantic Runtime

    private let session:
        MSRUApplicationShellSession


    // MARK: - Platform Renderer

    private let shellRenderer:
        MacApplicationShellRenderer


    // MARK: - Platform

    let toolbarAdapter:
        MacToolbarAdapter

    private let rootViewController:
        MSRUMacRootViewController

    private var canvasHostingController:
        NSHostingController<AnyView>?

    let windowController:
        MacApplicationWindowController


    // MARK: - Init

    init(
        scene:
            SceneModel,
        splitAutosaveName: String? = "MSRU.MainSplitView"
    ) {

        self.scene =
            scene


        // ----------------------------------------------------
        // Semantic Runtime
        // ----------------------------------------------------

        let session =
            MSRUApplicationShellSession(
                scene:
                    scene
            )


        self.session =
            session


        let initialShell =
            session.resolve()


        // ----------------------------------------------------
        // Navigation
        //
        // Navigation is the stable outer application region.
        // Workspace itself now comes from the Runtime.
        // ----------------------------------------------------

        let navigationController =
            MacHostingControllerFactory
                .make(
                    rootView:
                        SidebarPaneView(
                            scene:
                                scene
                        )
                )


        // ----------------------------------------------------
        // Semantic → macOS Renderer
        // ----------------------------------------------------

        let shellRenderer =
            MacApplicationShellRenderer(
                navigationViewController:
                    navigationController,
                shell:
                    initialShell,
                configuration:
                    .init(
                        split:
                            .init(
                                autosaveName:
                                    splitAutosaveName,
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
                                            500,
                                        automaticallyAdjustsSafeAreaInsets:
                                            true
                                    )
                            ),

                        /*
                         MSRU explicitly chooses its application
                         `.activity` context as the native right-hand
                         context region.

                         AppFoundation does not make this decision.
                         */

                        context:
                            .init(
                                region:
                                    .init(
                                        canCollapse:
                                            true,
                                        allowsFullHeightLayout:
                                            true,
                                        minimumThickness:
                                            280,
                                        maximumThickness:
                                            420
                                    ),
                                resolve: {
                                    shell in

                                    let contexts =
                                        shell
                                            .applicationContexts


                                    precondition(
                                        contexts.count
                                        ==
                                        1,
                                        """
                                        MSRU expects exactly one
                                        application context.
                                        """
                                    )


                                    return
                                        contexts
                                            .first
                                }
                            ),

                        /*
                         MSRU currently has one persistent
                         application-level accessory: Mini Player.
                         */

                        applicationAccessory:
                            .init(
                                resolve: {
                                    shell in

                                    let accessories =
                                        shell
                                            .applicationAccessories


                                    precondition(
                                        accessories.count
                                        ==
                                        1,
                                        """
                                        MSRU expects exactly one
                                        application accessory.
                                        """
                                    )


                                    return
                                        accessories
                                            .first
                                }
                            ),

                        rendersWorkspaceAccessory:
                            true
                    ),
                isContextPresented:
                    scene
                        .isQueuePresented
            )


        self.shellRenderer =
            shellRenderer


        // ----------------------------------------------------
        // Semantic Actions → Native Presentation
        // ----------------------------------------------------

        session.installShellActions(
            toggleQueue: {
                [weak shellRenderer]
                in

                shellRenderer?
                    .toggleContextPresentation()
            },
            revealInFinder: {
                url in

                PlatformFileViewer
                    .revealInFinder(
                        url: url
                    )
            }
        )


        shellRenderer
            .splitController
            .onContextPresentationChange = {
                [weak scene]
                isPresented in

                scene?
                    .isQueuePresented =
                        isPresented
            }


        // ----------------------------------------------------
        // Product-specific Navigation Accessory
        // ----------------------------------------------------

        let sidebarAccessory =
            MacSplitAccessoryHostingController(
                rootView:
                    SidebarBottomAccessoryView(
                        onOpenSettings: {
                            [weak scene]
                            in

                            scene?
                                .navigation
                                .select(
                                    .settings
                                )
                        }
                    )
            )


        shellRenderer
            .splitController
            .addAccessory(
                sidebarAccessory,
                to:
                    .navigation,
                edge:
                    .bottom
            )



        // ----------------------------------------------------
        // Semantic Toolbar
        // ----------------------------------------------------

        let toolbarAdapter =
            MacToolbarAdapter(
                identifier:
                    "MSRU.MainToolbar"
            ) {
                [weak session]
                in

                session?
                    .resolve()
                    .toolbar
                ??
                ResolvedToolbarPresentation()
            }


        self.toolbarAdapter =
            toolbarAdapter


        // ----------------------------------------------------
        // Native Window
        // ----------------------------------------------------

        let rootViewController =
            MSRUMacRootViewController(
                shellController:
                    shellRenderer
                        .splitController
            )

        self.rootViewController =
            rootViewController

        self.windowController =
            MacApplicationWindowController(
                contentViewController:
                    rootViewController,
                configuration:
                    MacWindowConfiguration(
                        title:
                            "MSRU"
                    ),
                toolbarAdapter:
                    toolbarAdapter
            )


        observePresentation()
        updateCanvasPresentation()
    }


    // MARK: - Runtime Observation

    private func observePresentation() {

        guard !scene.isClosed else { return }

        withObservationTracking {

            // Resolving also observes query text and enabled predicates on this route.
            _ = session.resolve()
            _ = scene.isQueuePresented
            _ = scene.activeContextPane
            _ = scene.isNowPlayingPresented

        } onChange: {
            [weak self]
            in

            Task {
                @MainActor
                [weak self]
                in

                guard
                    let self, !self.scene.isClosed
                else {

                    return
                }


                let shell =
                    session
                        .resolve()


                /*
                 One semantic snapshot updates both:
                 - native Workspace / Context / Accessories
                 - native Toolbar

                 There is no second route-resolution path.
                 */

                shellRenderer
                    .apply(
                        shell
                    )


                if shellRenderer.isContextPresented != scene.isQueuePresented {
                    shellRenderer.setContextPresented(scene.isQueuePresented)
                }
                updateCanvasPresentation()
                toolbarAdapter
                    .reload()


                observePresentation()
            }
        }
    }

    private func updateCanvasPresentation() {
        if scene.isNowPlayingPresented {
            if canvasHostingController == nil {
                let canvas = NowPlayingCanvasView(
                    playback: scene.application.playback,
                    onClose: { [weak self] in
                        self?.scene.setNowPlaying(presented: false)
                    }
                )
                let hosting = NSHostingController(rootView: AnyView(canvas))
                canvasHostingController = hosting
                rootViewController.setCanvasViewController(hosting)
            }
        } else {
            if canvasHostingController != nil {
                canvasHostingController = nil
                rootViewController.setCanvasViewController(nil)
            }
        }
    }
}


// MARK: - Root Window Container Controller

@MainActor
final class MSRUMacRootViewController: NSViewController {

    let shellController: NSViewController

    private var canvasController: NSViewController?

    init(shellController: NSViewController) {
        self.shellController = shellController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported.")
    }

    override func loadView() {
        self.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(shellController)
        view.addSubview(shellController.view)
        shellController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            shellController.view.topAnchor.constraint(equalTo: view.topAnchor),
            shellController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            shellController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            shellController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func setCanvasViewController(_ controller: NSViewController?) {
        if let current = canvasController {
            current.view.removeFromSuperview()
            current.removeFromParent()
            canvasController = nil
        }

        guard let controller else { return }

        canvasController = controller
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

#endif
