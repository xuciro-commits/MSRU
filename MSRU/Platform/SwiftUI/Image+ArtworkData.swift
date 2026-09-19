import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

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
