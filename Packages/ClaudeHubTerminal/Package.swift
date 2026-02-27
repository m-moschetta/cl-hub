// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ClaudeHubTerminal",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ClaudeHubTerminal", targets: ["ClaudeHubTerminal"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(path: "../ClaudeHubCore"),
    ],
    targets: [
        .target(
            name: "ClaudeHubTerminal",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                "ClaudeHubCore",
            ],
            path: "Sources"
        ),
    ]
)
