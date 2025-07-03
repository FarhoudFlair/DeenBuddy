// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeenAssist",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DeenAssistUI",
            targets: ["DeenAssistUI"]
        ),
        .library(
            name: "DeenAssistCore",
            targets: ["DeenAssistCore"]
        ),
        .library(
            name: "DeenAssistProtocols",
            targets: ["DeenAssistProtocols"]
        )
    ],
    dependencies: [
        // AdhanSwift for prayer time calculations
        .package(url: "https://github.com/batoulapps/adhan-swift", from: "1.0.0"),
        // Supabase for backend integration
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        // MARK: - Protocols Module
        .target(
            name: "DeenAssistProtocols",
            dependencies: []
        ),
        
        // MARK: - Core Module
        .target(
            name: "DeenAssistCore",
            dependencies: [
                "DeenAssistProtocols",
                .product(name: "Adhan", package: "adhan-swift"),
                .product(name: "Supabase", package: "supabase-swift")
            ]
        ),
        
        // MARK: - UI Module
        .target(
            name: "DeenAssistUI",
            dependencies: [
                "DeenAssistProtocols",
                "DeenAssistCore"
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "DeenAssistCoreTests",
            dependencies: ["DeenAssistCore"]
        ),
        .testTarget(
            name: "DeenAssistUITests",
            dependencies: ["DeenAssistUI"]
        )
    ]
)
