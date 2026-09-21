//
//  LocalAudioFormatSupport.swift
//  MSRU
//

import Foundation
import UniformTypeIdentifiers


nonisolated enum LocalAudioFormatSupport {

    // MARK: - Extensions

    static let supportedExtensions: Set<String> = [
        "mp3",
        "m4a",
        "aac",
        "wav",
        "aif",
        "aiff",
        "caf",
        "flac",
        "mp4",
        "dts",
        "dsd",
        "dsf",
        "dff",
        "alac",
        "ogg",
        "opus",
        "ape",
        "wv",
        "wma"
    ]

    // MARK: - Import Types

    static var importContentTypes: [UTType] {
        var types: [UTType] = [.audio, .folder]

        for ext in supportedExtensions {
            if let type = UTType(filenameExtension: ext) {
                if !types.contains(type) {
                    types.append(type)
                }
            } else if let type = UTType(filenameExtension: ext, conformingTo: .data) {
                if !types.contains(type) {
                    types.append(type)
                }
            }
        }

        return types
    }

    // MARK: - Support

    static func supports(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func supports(extension ext: String) -> Bool {
        supportedExtensions.contains(ext.lowercased())
    }

    // MARK: - Native Apple Formats
    static let nativeAppleExtensions: Set<String> = [
        "mp3",
        "m4a",
        "aac",
        "wav",
        "aif",
        "aiff",
        "caf",
        "flac",
        "alac",
        "mp4"
    ]

    static func isNativeAppleFormat(_ url: URL) -> Bool {
        nativeAppleExtensions.contains(url.pathExtension.lowercased())
    }

    static func isNativeAppleFormat(extension ext: String) -> Bool {
        nativeAppleExtensions.contains(ext.lowercased())
    }

    static func isDTS(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "dts"
    }
}
