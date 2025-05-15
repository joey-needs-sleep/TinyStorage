// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TinyStorage",
    platforms: [.iOS(.v18), .tvOS(.v18), .visionOS(.v2), .watchOS(.v11), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TinyStorage",
type: .dynamic,
            targets: ["TinyStorage"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TinyStorage",
            dependencies: []
        ),
        .testTarget(
            name: "TinyStorageTests",
            dependencies: ["TinyStorage"]
        )
    ]
)
