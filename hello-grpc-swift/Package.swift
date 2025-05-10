// swift-tools-version: 6.1

@preconcurrency import PackageDescription

let packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.0.0"),
    .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "1.0.0"),
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.1"),
]

extension Target {
    static let helloCommon: Target = .target(
        name: "HelloCommon",
        dependencies: [
            .product(name: "Logging", package: "swift-log"),
            .product(name: "GRPCCore", package: "grpc-swift"),
            .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
            .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ],
        path: "Sources/Common",
    )

    static let helloClient: Target = .executableTarget(
        name: "HelloClient",
        dependencies: [
            "HelloCommon",
        ],
        path: "Sources/Client"
    )

    static let helloServer: Target = .executableTarget(
        name: "HelloServer",
        dependencies: [
            "HelloCommon",
        ],
        path: "Sources/Server",
    )

    static let helloTests: Target = .testTarget(
        name: "HelloTests",
        dependencies: [
            "HelloCommon",
            "HelloServer",
        ],
        path: "Tests/helloTests"
    )
}

let package = Package(
    name: "hello-grpc-swift",
    platforms: [.macOS("15.0")],
    dependencies: packageDependencies,
    targets: [
        .helloCommon,
        .helloClient,
        .helloServer,
        .helloTests,
    ]
)
