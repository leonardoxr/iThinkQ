// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ThinkQ",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "ThinkQ", targets: ["ThinkQ"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.13.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.37.0")
    ],
    targets: [
        .executableTarget(
            name: "ThinkQ",
            dependencies: [
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl")
            ],
            path: "Sources/ThinkQ"
        ),
        .testTarget(
            name: "ThinkQTests",
            dependencies: ["ThinkQ"],
            path: "Tests/ThinkQTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
