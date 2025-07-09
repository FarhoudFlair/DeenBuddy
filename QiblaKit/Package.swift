// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "QiblaKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "QiblaKit",
            targets: ["QiblaKit"])
    ],
    targets: [
        .target(
            name: "QiblaKit",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("CoreMotion")
            ]
        ),
        .testTarget(
            name: "QiblaKitTests",
            dependencies: ["QiblaKit"])
    ]
)