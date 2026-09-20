//
//  PlatformImageDecoder.swift
//  AppFoundationUI
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public extension Image {
    /// Decodes raw artwork binary into a SwiftUI Image across supported platforms.
    init?(foundationArtworkData: Data) {
        #if canImport(AppKit)
        guard let image = NSImage(data: foundationArtworkData) else { return nil }
        self.init(nsImage: image)
        #elseif canImport(UIKit)
        guard let image = UIImage(data: foundationArtworkData) else { return nil }
        self.init(uiImage: image)
        #else
        return nil
        #endif
    }
}
