// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Hunter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Hunter", targets: ["Hunter"])
    ],
    targets: [
        .executableTarget(
            name: "Hunter",
            path: "Sources/Hunter",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HunterTests",
            dependencies: ["Hunter"],
            path: "Tests/HunterTests"
        )
    ]
)
