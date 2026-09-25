//
//  MSRUApp.swift
//  MSRU
//

import SwiftUI
import AppFoundation


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
            SettingsView(languageSettings: appDelegate.application.languageSettings)
                .frame(minWidth: 480, idealWidth: 520, minHeight: 240, idealHeight: 280)
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
                        .send(
                            .newScene
                        )
                }
                .keyboardShortcut(
                    "n",
                    modifiers:
                        .command
                )
            }
        }

        MenuBarExtra {
            MenuBarPlayerView(
                playback: appDelegate.playback,
                onOpenMainWindow: {
                    appDelegate.activateApp()
                },
                onQuitApp: {
                    NSApplication.shared.terminate(nil)
                }
            )
        } label: {
            MenuBarStatusItemLabel(
                playback: appDelegate.playback
            )
        }
        .menuBarExtraStyle(.window)

        #else

        WindowGroup {

            SwiftUISceneRootView(
                application:
                    application
            )
        }

        #endif
    }
}
