import Foundation
import Logging

public protocol Connection {
    var host: String? { get }
    var port: Int? { get }
    var backendHost: String? { get }
    var backendPort: Int? { get }
    var hasBackend: Bool { get }
}

public class HelloConn: Connection {
    let logger = Logger(label: "HelloConn")
    public var host: String?
    public var backendHost: String?
    public var port: Int?
    public var backendPort: Int?

    public var hasBackend: Bool {
        backendHost != nil && !backendHost!.isEmpty
    }

    public init() {
        // Get backend configuration from environment
        if let envHost = ProcessInfo.processInfo.environment["GRPC_SERVER"], !envHost.isEmpty {
            host = envHost
        } else {
            // 检测是否为 docker 环境
            let dockerHost: String = {
                if let cgroup = try? String(contentsOfFile: "/proc/1/cgroup", encoding: .utf8),
                   cgroup.contains("docker") || cgroup.contains("containerd")
                {
                    return "0.0.0.0"
                }
                // 兼容 macOS 本地开发
                #if os(macOS)
                    return "127.0.0.1"
                #else
                    return "0.0.0.0"
                #endif
            }()
            host = dockerHost
            logger.info("GRPC_SERVER 未设置，自动使用默认 host: \(dockerHost)")
        }

        if let portStr = ProcessInfo.processInfo.environment["GRPC_SERVER_PORT"] {
            if let port0 = Int(portStr) {
                port = port0
            }
        } else {
            // Set default port when not specified in environment
            port = 9996
        }

        // Get backend configuration from environment
        backendHost = ProcessInfo.processInfo.environment["GRPC_HELLO_BACKEND"]

        if let backendPortStr = ProcessInfo.processInfo.environment["GRPC_HELLO_BACKEND_PORT"] {
            if let port = Int(backendPortStr) {
                backendPort = port
            }
        }

        logger.info("Hello service port: \(port ?? 9996)")
        if hasBackend {
            logger.info("Backend configured: \(backendHost!):\(backendPort ?? 9996)")
        }
    }
}
