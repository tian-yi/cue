// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Cue",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Cue", targets: ["Cue"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Cue",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket")
            ],
            path: "Sources/Cue"
        ),
        .testTarget(
            name: "CueTests",
            dependencies: ["Cue"],
            path: "Tests/CueTests"
        )
    ]
)
