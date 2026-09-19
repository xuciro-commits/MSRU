//
//  LocalAudioFormatSupport.swift
//  MSRU
//

import Foundation
import UniformTypeIdentifiers


nonisolated enum LocalAudioFormatSupport {

    // MARK: - Extensions

    static let supportedExtensions:
        Set<String> = [

            "mp3",
            "m4a",
            "aac",
            "wav",
            "aif",
            "aiff",
            "caf",
            "flac",
            "mp4",

            // DTS
            "dts"
        ]


    // MARK: - Import Types

    static var importContentTypes:
        [UTType] {

        var types:
            [UTType] = [
                .audio
            ]


        /*
         DTS 在部分 macOS 环境下没有声明成
         public.audio 的 subtype。

         使用 filename extension 创建动态 UTType，
         让 NSOpenPanel / fileImporter 可以选择它。
         */

        if let dts =
            UTType(
                filenameExtension:
                    "dts",
                conformingTo:
                    .data
            ) {

            types.append(
                dts
            )
        }


        return types
    }


    // MARK: - Support

    static func supports(
        _ url:
            URL
    ) -> Bool {

        supportedExtensions
            .contains(
                url
                    .pathExtension
                    .lowercased()
            )
    }


    static func isDTS(
        _ url:
            URL
    ) -> Bool {

        url
            .pathExtension
            .lowercased()
        == "dts"
    }
}
