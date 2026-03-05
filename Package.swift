// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SnapForge",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SnapForge", targets: ["SnapForge"])
    ],
    targets: [
        .executableTarget(
            name: "SnapForge",
            path: "SnapForge",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "SnapForgeTests",
            dependencies: ["SnapForge"],
            path: "Tests/SnapForgeTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
