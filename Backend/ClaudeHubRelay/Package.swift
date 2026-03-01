// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeHubRelay",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../../Packages/ClaudeHubRemote"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeHubRelay",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "ClaudeHubRemote", package: "ClaudeHubRemote"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/ClaudeHubRelay"
        ),
    ]
)
