// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ClaudeHubCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ClaudeHubCore", targets: ["ClaudeHubCore"]),
    ],
    targets: [
        .target(name: "ClaudeHubCore", path: "Sources"),
    ]
)
