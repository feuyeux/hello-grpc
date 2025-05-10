import Foundation
import XCTest

@testable import Common

final class VersionTests: XCTestCase {
    func testGetVersion() {
        // Get the version string
        let version = Utils.getVersion()
        print("Swift gRPC version: \(version)")

        // Test that the version string starts with the expected prefix
        XCTAssertTrue(
            version.hasPrefix("grpc.version="),
            "Version string should start with 'grpc.version='"
        )

        // Test that the version is not empty (beyond the prefix)
        XCTAssertGreaterThan(
            version.count,
            "grpc.version=".count,
            "Version string should be longer than just the prefix"
        )
    }

    static var allTests = [
        ("testGetVersion", testGetVersion),
    ]
}
