//
//  MSRUApp.swift
//  MSRU
//

import SwiftUI


@main
@MainActor
struct MSRUApp:
    App {

    #if os(macOS)

    @NSApplicationDelegateAdaptor(
        AppDelegate.self
    )
    private var appDelegate


    #else

    @State
    private var application =
        ApplicationModel()

    #endif


    var body:
        some Scene {

        #if os(macOS)

        Settings {

            EmptyView()
        }
        .commands {

            CommandGroup(
                replacing:
                    .newItem
            ) {

                Button(
                    "New Window"
                ) {

                    appDelegate
                        .openNewScene()
                }
                .keyboardShortcut(
                    "n",
                    modifiers:
                        .command
                )
            }
        }


        #else

        WindowGroup {

            iPadRootView(
                application:
                    application
            )
            .task {

                application
                    .start()
            }
        }

        #endif
    }
}
