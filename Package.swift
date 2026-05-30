// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YTNoAds",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "YTNoAds", targets: ["YTNoAds"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "YTNoAds",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket")
            ],
            path: "Sources/YTNoAds"
        ),
        .testTarget(
            name: "YTNoAdsTests",
            dependencies: ["YTNoAds"],
            path: "Tests/YTNoAdsTests"
        )
    ]
)
