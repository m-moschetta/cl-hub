// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ClaudeHubRelay",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../../Packages/ClaudeHubRemote"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeHubRelay",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "ClaudeHubRemote", package: "ClaudeHubRemote"),
            ],
            path: "Sources/ClaudeHubRelay"
        ),
    ]
)
