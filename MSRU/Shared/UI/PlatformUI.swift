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
