import Foundation

import Logging

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
