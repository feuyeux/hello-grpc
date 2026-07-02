// swift-tools-version: 6.1

@preconcurrency import PackageDescription

let packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.0.0"),
    .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "1.0.0"),
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.1"),
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", from: "2.0.0"),
    // Pinned to >= 2.37.1: that release adds _WINSOCKAPI_/NOMINMAX/NOCRYPT
    // defines for CNIOBoringSSL on Windows, fixing winsock2.h/winsock.h
    // redefinition errors that block `swift build` on Windows.
    .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.37.1"),
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
            .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
            .product(name: "StdoutExporter", package: "opentelemetry-swift-core"),
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
