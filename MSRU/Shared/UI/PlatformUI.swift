//
//  PlatformUI.swift
//  MSRU
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import AppFoundation

// MARK: - Color Platform Extension

extension Color {
    /// Cross-platform window/system background color for macOS and iOS.
    static var platformWindowBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}

// MARK: - Image Artwork Decoder

extension Image {
    /// Decode embedded artwork at the platform boundary; callers own presentation and fallback.
    init?(artworkData: Data) {
        #if canImport(AppKit)
        guard let image = NSImage(data: artworkData) else { return nil }
        self.init(nsImage: image)
        #elseif canImport(UIKit)
        guard let image = UIImage(data: artworkData) else { return nil }
        self.init(uiImage: image)
        #else
        return nil
        #endif
    }
}

// MARK: - Locale Override

extension View {
    @ViewBuilder
    func applyLocaleOverride(_ locale: Locale?) -> some View {
        if let locale {
            self.environment(\.locale, locale)
        } else {
            self
        }
    }
}
