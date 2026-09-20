//
//  Color+Platform.swift
//  MSRU
//

import SwiftUI

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
