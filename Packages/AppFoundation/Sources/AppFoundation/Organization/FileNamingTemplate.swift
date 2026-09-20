//
//  FileNamingTemplate.swift
//  AppFoundation
//
//  Created for Identity Resolution Engine Phase 5.
//

import Foundation

/// beets-inspired file naming template engine with strict filesystem sanitization.
public struct FileNamingTemplate: Sendable, Equatable, Codable {

    /// Default hierarchical organization template: `"$artist/$album ($year)/$track - $title"`
    public static let defaultTemplate = "$artist/$album ($year)/$track - $title"

    public var template: String

    public init(template: String = FileNamingTemplate.defaultTemplate) {
        self.template = template
    }

    /// Renders the relative path given metadata properties and target file extension.
    public func render(
        artist: String,
        album: String,
        year: Int?,
        trackNumber: Int?,
        title: String,
        fileExtension: String
    ) -> String {
        let cleanArtist = Self.sanitize(artist.isEmpty ? "Unknown Artist" : artist)
        let cleanAlbum = Self.sanitize(album.isEmpty ? "Unknown Album" : album)
        let cleanTitle = Self.sanitize(title.isEmpty ? "Unknown Title" : title)
        let cleanExt = fileExtension.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "."))

        let yearStr = year.map { String($0) } ?? ""
        let yearInParens = yearStr.isEmpty ? "" : "(\(yearStr))"

        let trackStr: String
        if let num = trackNumber, num > 0 {
            trackStr = String(format: "%02d", num)
        } else {
            trackStr = "00"
        }

        var result = template
        result = result.replacingOccurrences(of: "$artist", with: cleanArtist)
        result = result.replacingOccurrences(of: "$album ($year)", with: yearInParens.isEmpty ? cleanAlbum : "\(cleanAlbum) \(yearInParens)")
        result = result.replacingOccurrences(of: "$album", with: cleanAlbum)
        result = result.replacingOccurrences(of: "$year", with: yearStr)
        result = result.replacingOccurrences(of: "$track", with: trackStr)
        result = result.replacingOccurrences(of: "$title", with: cleanTitle)

        // Split by directory separators to sanitize each component individually
        let components = result.components(separatedBy: "/")
            .map { Self.sanitize($0) }
            .filter { !$0.isEmpty }

        let relativeDirectory = components.dropLast().joined(separator: "/")
        let filenameOnly = components.last ?? cleanTitle

        let finalFilename: String
        if cleanExt.isEmpty {
            finalFilename = filenameOnly
        } else {
            finalFilename = "\(filenameOnly).\(cleanExt)"
        }

        if relativeDirectory.isEmpty {
            return finalFilename
        } else {
            return "\(relativeDirectory)/\(finalFilename)"
        }
    }

    /// Sanitizes an individual directory or file name component according to POSIX & APFS rules.
    ///
    /// - Replaces invalid characters (`/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`)
    /// - Strips leading/trailing dots and whitespace
    /// - Truncates component length to 255 bytes UTF-8 max
    public static func sanitize(_ component: String) -> String {
        var clean = component

        // Replace colons with dashes
        clean = clean.replacingOccurrences(of: ":", with: " - ")

        // Replace slashes and other illegal characters with underscores
        let illegalCharacters = CharacterSet(charactersIn: "/\\*?\"<>|\0")
        clean = clean.components(separatedBy: illegalCharacters).joined(separator: "_")

        // Collapse consecutive spaces and underscores
        while clean.contains("  ") {
            clean = clean.replacingOccurrences(of: "  ", with: " ")
        }
        while clean.contains("__") {
            clean = clean.replacingOccurrences(of: "__", with: "_")
        }

        // Trim whitespace and periods
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        if clean.isEmpty {
            clean = "Untitled"
        }

        // Truncate to 255 bytes max for APFS/HFS+ compatibility
        if clean.utf8.count > 255 {
            var truncated = ""
            for char in clean {
                if (truncated + String(char)).utf8.count <= 250 {
                    truncated.append(char)
                } else {
                    break
                }
            }
            clean = truncated
        }

        return clean
    }
}
