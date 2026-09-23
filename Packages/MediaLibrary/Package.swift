// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MediaLibrary",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "MediaLibrary",
            targets: ["MediaLibrary"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MediaLibrary",
            dependencies: []
        ),
        .testTarget(
            name: "MediaLibraryTests",
            dependencies: ["MediaLibrary"]
        )
    ]
)
