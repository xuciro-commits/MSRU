#if os(iOS)

import SwiftUI


struct iPadRootView: View {

    var body: some View {

        NavigationSplitView {

            List {

                Label(
                    "Listen Now",
                    systemImage:
                        "play.circle"
                )
            }

        } detail: {

            Text(
                "MSRU iPad"
            )
        }
    }
}

#endif
