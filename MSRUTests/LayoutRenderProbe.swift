#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import MSRU

@MainActor
struct LayoutRenderProbe {
    @Test
    func renderCompactFixtures() async throws {
        let output = URL(fileURLWithPath: "/tmp/msru-layout-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func render<V: View>(_ view: V, name: String, size: NSSize) async throws {
            let host = NSHostingView(rootView: view.environment(\.colorScheme, .light))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFront(nil)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(200))
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent(name + ".png"))
        }
        let playback = MSRUPreviewData.makePlaybackController()
        playback.playbackQueue.start(PlaybackItem(local: MSRUPreviewData.localTracks[0]))
        try await render(MiniPlayerBar(playback: playback, onToggleQueue: {})
            .frame(width: 320).padding(16).background(Color.white), name: "mini-320", size: NSSize(width: 352, height: 92))
        let application = MSRUPreviewData.makeApplication(savedTracks:
            MSRUPreviewData.localTracks.map { LibraryTrack(local: $0) })
        await application.library.load()
        let scene = SceneModel(application: application, section: .library)
        try await render(LibraryView(feature: scene.libraryFeature, localStore: application.localLibrary,
            playback: application.playback, selectedLocalTrack: .constant(nil), onAddMusic: {})
            .frame(width: 360, height: 640).background(Color.white), name: "library-360", size: NSSize(width: 360, height: 640))
    }
}
#endif
