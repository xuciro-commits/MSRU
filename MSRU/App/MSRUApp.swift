import SwiftUI


@main
struct MSRUApp: App {

    #if os(macOS)

    @NSApplicationDelegateAdaptor(
        AppDelegate.self
    )
    private var appDelegate

    #endif


    var body: some Scene {

        #if os(macOS)

        Settings {
            EmptyView()
        }

        #else

        WindowGroup {
            iPadRootView()
        }

        #endif
    }
}
