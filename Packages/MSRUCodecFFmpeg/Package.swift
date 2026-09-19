// swift-tools-version: 6.0

import PackageDescription


let package = Package(

    name:
        "MSRUCodecFFmpeg",

    platforms: [
        .macOS(
            .v15
        ),
        .iOS(
            .v18
        )
    ],

    products: [

        .library(
            name:
                "MSRUCodecFFmpeg",
            targets: [
                "MSRUCodecFFmpeg"
            ]
        )
    ],

    targets: [

        /*
         MSRU FFmpeg Micro

         Static-library XCFramework containing only
         the FFmpeg components required by MSRU's
         extended DTS / DCA audio pipeline.

         Platforms:

         - macOS arm64
         - iOS arm64
         - iOS Simulator arm64 + x86_64

         This is deliberately not a complete FFmpeg
         distribution and does not contain FFmpegKit.
         */

        .binaryTarget(
            name:
                "MSRUFFmpegMicro",
            path:
                "Vendor/MSRUFFmpegMicro.xcframework"
        ),


        /*
         C boundary between the public Swift codec
         package and FFmpeg's C API.
         */

        .target(
            name:
                "CFFmpegBridge",
            dependencies: [
                "MSRUFFmpegMicro"
            ],
            publicHeadersPath:
                "include"
        ),


        /*
         Swift-facing codec implementation.
         */

        .target(
            name:
                "MSRUCodecFFmpeg",
            dependencies: [
                "CFFmpegBridge"
            ]
        )
    ]
)

