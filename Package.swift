// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PRMenu",
    platforms: [
        .macOS(.v15),
    ],
    targets: [
        .executableTarget(
            name: "PRMenu",
            path: "Sources/PRMenu"
        ),
    ]
)
