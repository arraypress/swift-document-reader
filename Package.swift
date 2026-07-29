// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocumentReader",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26)
    ],
    products: [
        .library(
            name: "DocumentReader",
            targets: ["DocumentReader"]
        ),
    ],
    targets: [
        .target(
            name: "DocumentReader",
            dependencies: []
        ),
        .testTarget(
            name: "DocumentReaderTests",
            dependencies: ["DocumentReader"]
        ),
    ]
)
