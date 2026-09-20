#if os(macOS)
import AppKit
import SwiftUI
import Testing
import AppFoundation
import AppFoundationUI
@testable import MSRU

@MainActor
struct LayoutRenderProbe {
    @Test
    func renderCompactFixtures() async throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("msru-layout-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let publicOutput = URL(fileURLWithPath: "/tmp/msru-layout-qa", isDirectory: true)
        _ = try? FileManager.default.createDirectory(at: publicOutput, withIntermediateDirectories: true)
        print("LAYOUT_QA_DIR: \(output.path)")

        func render<V: View>(_ view: V, name: String, size: NSSize) async throws {
            let host = NSHostingView(rootView: view.environment(\.colorScheme, .light))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFront(nil)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(250))
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            let fileURL = output.appendingPathComponent(name + ".png")
            try png.write(to: fileURL)
            _ = try? png.write(to: publicOutput.appendingPathComponent(name + ".png"))
            #expect(png.count > 0)
        }

        let playback = MSRUPreviewData.makePlaybackController()
        playback.playbackQueue.start(PlaybackItem(local: MSRUPreviewData.localTracks[0]))

        // 1. Ultra-compact MiniPlayer (320pt)
        try await render(
            MiniPlayerBar(playback: playback, onToggleQueue: {})
                .frame(width: 320)
                .padding(16)
                .background(Color.white),
            name: "mini-320",
            size: NSSize(width: 352, height: 92)
        )

        // 2. Mid-compact MiniPlayer (480pt)
        try await render(
            MiniPlayerBar(playback: playback, onToggleQueue: {})
                .frame(width: 480)
                .padding(16)
                .background(Color.white),
            name: "mini-480",
            size: NSSize(width: 512, height: 92)
        )

        // 3. Standard MiniPlayer (800pt)
        try await render(
            MiniPlayerBar(playback: playback, onToggleQueue: {})
                .frame(width: 800)
                .padding(16)
                .background(Color.white),
            name: "mini-800",
            size: NSSize(width: 832, height: 92)
        )

        // 4. Compact Library View (360pt)
        let application = MSRUPreviewData.makeApplication(savedTracks:
            MSRUPreviewData.localTracks.map { LibraryTrack(local: $0) })
        await application.library.load()
        let scene = SceneModel(application: application, section: .library)
        try await render(
            LibraryView(
                feature: scene.libraryFeature,
                localStore: application.localLibrary,
                playback: application.playback,
                selectedLocalTrack: .constant(nil),
                onAddMusic: {}
            )
            .frame(width: 360, height: 640)
            .background(Color.white),
            name: "library-360",
            size: NSSize(width: 360, height: 640)
        )

        // 5. Standard Library View (700pt)
        try await render(
            LibraryView(
                feature: scene.libraryFeature,
                localStore: application.localLibrary,
                playback: application.playback,
                selectedLocalTrack: .constant(nil),
                onAddMusic: {}
            )
            .frame(width: 700, height: 500)
            .background(Color.white),
            name: "library-700",
            size: NSSize(width: 700, height: 500)
        )

        // 6. Compact Radio View (360pt)
        let radioFeature = MSRUPreviewData.makeRadioFeature()
        try await render(
            RadioView(
                feature: radioFeature,
                selectedStation: RadioStation.defaultStations.first,
                onSelectStation: { _ in }
            )
            .frame(width: 360, height: 640)
            .background(Color.white),
            name: "radio-360",
            size: NSSize(width: 360, height: 640)
        )

        // 7. Compact Application Shell (360pt)
        let shell = ApplicationShellResolver<String, String, String>(
            shell: ApplicationShellPresentation(
                accessories: [
                    AccessoryPresentation(id: "mini-player", scope: .application) { (_: String) in
                        MiniPlayerBar(playback: playback, onToggleQueue: {})
                            .frame(height: 60)
                    }
                ]
            ),
            workspace: { _, _ in
                WorkspacePresentation(identity: WorkspaceIdentity(title: "Library")) { (_: String) in
                    LibraryView(
                        feature: scene.libraryFeature,
                        localStore: application.localLibrary,
                        playback: application.playback,
                        selectedLocalTrack: .constant(nil),
                        onAddMusic: {}
                    )
                }
            }
        ).resolve(route: "library", workspaceContext: "", shellContext: "")

        try await render(
            SwiftUIApplicationShell(shell: shell, isContextPresented: .constant(false)) {
                SidebarPaneView(scene: scene)
            }
            .frame(width: 360, height: 640)
            .background(Color.white),
            name: "shell-compact-360",
            size: NSSize(width: 360, height: 640)
        )

        // 8. Browse View Layout Verification
        try await render(
            BrowseView(feature: scene.browse)
                .frame(width: 800, height: 600)
                .background(Color.white),
            name: "browse-800",
            size: NSSize(width: 800, height: 600)
        )
    }
}
#endif
