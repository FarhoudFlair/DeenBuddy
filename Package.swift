// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeenAssist",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DeenAssistCore",
            targets: ["DeenAssistCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/batoulapps/adhan-swift", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "DeenAssistCore",
            dependencies: [
                .product(name: "Adhan", package: "adhan-swift")
            ],
            path: "Sources/DeenAssistCore"
        ),
        .testTarget(
            name: "DeenAssistCoreTests",
            dependencies: ["DeenAssistCore"],
            path: "Tests/DeenAssistCoreTests"
        ),
    ]
)
