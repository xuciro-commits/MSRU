//
//  AudioCodecBackend.swift
//  MSRU
//

import Foundation


struct PCMStreamFormat:
    Sendable {

    let sampleRate:
        Double

    let channels:
        UInt32

    let duration:
        TimeInterval?
}


struct PCMFrameBlock:
    Sendable {

    let left:
        [Float]

    let right:
        [Float]

    let frameCount:
        Int
}


protocol PCMDecodeSession:
    Sendable {

    func read(
        maxFrames:
            Int
    ) async throws
        -> PCMFrameBlock?


    func seek(
        to seconds:
            TimeInterval
    ) async throws


    func close()
        async
}


struct AudioCodecOpenResult:
    Sendable {

    let format:
        PCMStreamFormat

    let session:
        any PCMDecodeSession
}


protocol AudioCodecBackend:
    Sendable {

    var id:
        String {
        get
    }


    func canDecode(
        _ url:
            URL
    ) -> Bool


    func open(
        _ url:
            URL
    ) async throws
        -> AudioCodecOpenResult
}


// MARK: - Extended Formats

enum ExtendedAudioFormatSupport {

    static let extensions:
        Set<String> = [

            "dts"
        ]


    static func supports(
        _ url:
            URL
    ) -> Bool {

        extensions
            .contains(
                url
                    .pathExtension
                    .lowercased()
            )
    }
}
