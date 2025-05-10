import Foundation
import Testing

@testable import HelloCommon

@Suite("Version Tests")
struct VersionTests {
    @Test("Test Version String Format")
    func testGetVersion() {
        // Get the version string
        let version = Utils.getVersion()
        print("Swift gRPC version: \(version)")

        // Test that the version string starts with the expected prefix
        #expect(version.hasPrefix("grpc.version="), "Version string should start with 'grpc.version='")

        // Test that the version is not empty (beyond the prefix)
        #expect(version.count > "grpc.version=".count, "Version string should be longer than just the prefix")
    }
}
