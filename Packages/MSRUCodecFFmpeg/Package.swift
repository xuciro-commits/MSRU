// swift-tools-version: 6.0

import PackageDescription


let package = Package(

    name:
        "MSRUCodecFFmpeg",

    platforms: [
        .macOS(.v15)
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
         我们自己构建的 FFmpeg Micro。

         不是 .framework，
         而是 static-library XCFramework。

         因此：
         - 不嵌入 App Frameworks
         - 不存在 macOS shallow framework 问题
         - 不携带完整 FFmpegKit dependency graph
         */

        .binaryTarget(
            name:
                "MSRUFFmpegMicro",
            path:
                "Vendor/MSRUFFmpegMicro.xcframework"
        ),


        .target(
            name:
                "CFFmpegBridge",
            dependencies: [
                "MSRUFFmpegMicro"
            ],
            publicHeadersPath:
                "include"
        ),


        .target(
            name:
                "MSRUCodecFFmpeg",
            dependencies: [
                "CFFmpegBridge"
            ]
        )
    ]
)
