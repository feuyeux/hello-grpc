// swift-tools-version: 5.8.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.19.1"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
//    .package(
//        url: "https://github.com/apple/swift-nio-http2.git",
//        from: "1.24.1"
//    ),
//    .package(
//        url: "https://github.com/apple/swift-nio-transport-services.git",
//        from: "1.15.0"
//    ),
//    .package(
//        url: "https://github.com/apple/swift-nio-extras.git",
//        from: "1.4.0"
//    ),
    .package(
            url: "https://github.com/apple/swift-protobuf.git",
            from: "1.24.0"
    ),
    .package(
            url: "https://github.com/apple/swift-log.git",
            from: "1.5.3"
    ),
    .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.2.3"
    ),
]

extension Target.Dependency {
    static let helloCommon: Self = .target(name: "HelloCommon")

    // Product dependencies
    static let argumentParser: Self = .product(
            name: "ArgumentParser",
            package: "swift-argument-parser"
    )
    static let grpc: Self = .product(name: "GRPC", package: "grpc-swift")
    static let nio: Self = .product(name: "NIO", package: "swift-nio")
    static let nioConcurrencyHelpers: Self = .product(
            name: "NIOConcurrencyHelpers",
            package: "swift-nio"
    )
    static let nioCore: Self = .product(name: "NIOCore", package: "swift-nio")
    static let nioEmbedded: Self = .product(name: "NIOEmbedded", package: "swift-nio")
    static let nioExtras: Self = .product(name: "NIOExtras", package: "swift-nio-extras")
    static let nioFoundationCompat: Self = .product(name: "NIOFoundationCompat", package: "swift-nio")
    static let nioHTTP1: Self = .product(name: "NIOHTTP1", package: "swift-nio")
    static let nioHTTP2: Self = .product(name: "NIOHTTP2", package: "swift-nio-http2")
    static let nioPosix: Self = .product(name: "NIOPosix", package: "swift-nio")
    static let nioSSL: Self = .product(name: "NIOSSL", package: "swift-nio-ssl")
    static let nioTLS: Self = .product(name: "NIOTLS", package: "swift-nio")
    static let nioTransportServices: Self = .product(
            name: "NIOTransportServices",
            package: "swift-nio-transport-services"
    )
    static let logging: Self = .product(name: "Logging", package: "swift-log")
    static let protobuf: Self = .product(name: "SwiftProtobuf", package: "swift-protobuf")
}

extension Target {
    static let helloCommon: Target = .target(
            name: "HelloCommon",
            dependencies: [
                .grpc,
                .nio,
                .protobuf,
                .logging,
            ],
            path: "Sources/Common",
            exclude: [
                "landing.proto",
            ]
    )

    static let helloClient: Target = .executableTarget(
            name: "HelloClient",
            dependencies: [
                .grpc,
                .helloCommon,
                .nioCore,
                .nioPosix,
                .argumentParser,
            ],
            path: "Sources/Client"
    )

    static let helloServer: Target = .executableTarget(
            name: "HelloServer",
            dependencies: [
                .grpc,
                .helloCommon,
                .nioCore,
                .nioConcurrencyHelpers,
                .nioPosix,
                .argumentParser,
            ],
            path: "Sources/Server"
    )

    static let helloCommonUT: Target = .testTarget(
            name: "HelloCommonTest",
            dependencies: [
                "HelloCommon",
            ],
            path: "Tests/helloTests"
    )
}

let package = Package(
        name: "hello-grpc-swift",
        dependencies: packageDependencies,
        targets: [
            .helloCommon,
            .helloClient,
            .helloServer,
            .helloCommonUT,
        ]
)
