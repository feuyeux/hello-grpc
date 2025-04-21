@testable import HelloCommon
import Logging
import XCTest

final class helloTests: XCTestCase {
    let logger = Logger(label: "HelloUT")

    func testExample() throws {
        let conn = HelloConn()
        XCTAssertEqual(conn.port, 9996)
    }

    override func setUp() {
        super.setUp()
        logger.info("UT Set up")
    }

    override func tearDown() {
        super.tearDown()
        logger.info("UT Tear down")
    }
}
