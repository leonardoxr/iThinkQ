// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "iThinkQ",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "iThinkQ", targets: ["IThinkQ"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.13.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.37.0")
    ],
    targets: [
        .executableTarget(
            name: "IThinkQ",
            dependencies: [
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl")
            ],
            path: "Sources/iThinkQ"
        ),
        .testTarget(
            name: "IThinkQTests",
            dependencies: ["IThinkQ"],
            path: "Tests/iThinkQTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
