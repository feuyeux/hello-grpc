import Foundation
import Logging

#if compiler(>=5.6)

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol Connection {
    var port: Int { get }
}

public class HelloConn: Connection {
    let logger = Logger(label: "HelloConn")

    public var port: Int = 9996

    public init() {
        // let user = ProcessInfo.processInfo.environment["USER"]
        // logger.info("Hello \(user!)")
    }
}
#endif // compiler(>=5.6)
