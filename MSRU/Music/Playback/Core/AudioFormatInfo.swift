//
//  AudioFormatInfo.swift
//  MSRU
//

import Foundation

struct AudioFormatInfo: Equatable, Sendable {
    let codec: String
    let sampleRate: String?
    let bitDepth: String?
    let bitrate: String?
    let isLossless: Bool
    let isHiRes: Bool

    var summaryText: String {
        var parts: [String] = [codec]
        if let bitrate {
            parts.append(bitrate)
        }
        if let sampleRate {
            parts.append(sampleRate)
        }
        return parts.joined(separator: " • ")
    }
}
