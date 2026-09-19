// swift-tools-version: 6.0

import PackageDescription


let package = Package(
    name: "AppFoundation",

    products: [
        .library(
            name: "AppFoundation",
            targets: [
                "AppFoundation"
            ]
        )
    ],

    targets: [
        .target(
            name: "AppFoundation"
        ),

        .testTarget(
            name: "AppFoundationTests",
            dependencies: [
                "AppFoundation"
            ]
        )
    ]
)
