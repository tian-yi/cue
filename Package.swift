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
    targets: [
        .executableTarget(
            name: "YTNoAds",
            path: "Sources/YTNoAds"
        ),
        .testTarget(
            name: "YTNoAdsTests",
            dependencies: ["YTNoAds"],
            path: "Tests/YTNoAdsTests"
        )
    ]
)
