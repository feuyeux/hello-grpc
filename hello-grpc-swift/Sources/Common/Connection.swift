import Foundation
import Logging

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public protocol Connection {
    var port: Int { get }
}

public class HelloConn: Connection {
    let logger = Logger(label: "HelloConn")
    public var port: Int = 9996
    public init() {
        logger.info("Hello")
    }
}
