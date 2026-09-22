//
//  PlatformFileViewer.swift
//  MSRU
//
//  Cross-platform file viewer utility.
//

import Foundation
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum PlatformFileViewer {
    @MainActor
    public static func revealInFinder(url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #elseif canImport(UIKit)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
