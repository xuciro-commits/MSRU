// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SubsonicKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "SubsonicKit",
            targets: ["SubsonicKit"]
        )
    ],
    dependencies: [
        .package(path: "../MediaLibrary")
    ],
    targets: [
        .target(
            name: "SubsonicKit",
            dependencies: [
                .product(name: "MediaLibrary", package: "MediaLibrary")
            ]
        ),
        .testTarget(
            name: "SubsonicKitTests",
            dependencies: ["SubsonicKit"]
        )
    ]
)
