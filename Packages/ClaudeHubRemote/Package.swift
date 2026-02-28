// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ClaudeHubRemote",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "ClaudeHubRemote", targets: ["ClaudeHubRemote"]),
    ],
    targets: [
        .target(name: "ClaudeHubRemote"),
    ]
)
