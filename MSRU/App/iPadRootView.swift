#if os(iOS)

import SwiftUI


struct iPadRootView:
    View {

    // MARK: - Scene Scope

    @State
    private var scene:
        SceneModel


    // MARK: - Init

    init(
        application:
            ApplicationModel
    ) {

        _scene =
            State(
                initialValue:
                    SceneModel(
                        application:
                            application
                    )
            )
    }


    // MARK: - Body

    var body:
        some View {

        NavigationSplitView {

            SidebarPaneView(
                scene:
                    scene
            )

        } detail: {

            MainContentView(
                scene:
                    scene
            )
        }
    }
}

#endif
