// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AutoForti",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AutoForti",
            path: "Sources/AutoForti",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
            ]
        )
    ]
)
