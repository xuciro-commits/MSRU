//
//  PlatformFileViewer.swift
//  MSRU
//

#if os(macOS)
import AppKit

enum PlatformFileViewer {
    @MainActor
    static func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
#endif
