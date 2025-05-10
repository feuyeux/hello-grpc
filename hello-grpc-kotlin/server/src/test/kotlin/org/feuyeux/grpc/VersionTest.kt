package org.feuyeux.grpc

import org.junit.jupiter.api.Test
import kotlin.test.assertTrue
import kotlin.test.assertFalse
import org.apache.logging.log4j.kotlin.logger

class VersionTest {
    private val log = logger()

    @Test
    fun testGetVersion() {
        // Create a ProtoServer instance to access the getVersion method
        val server = ProtoServer()
        
        // Get the version string
        val version = server.getVersion()
        log.info("Kotlin gRPC version: $version")
        
        // Test that the string starts with the expected prefix
        assertTrue(version.startsWith("grpc.version="), "Version string should start with 'grpc.version='")
        
        // Test that the version is not empty (beyond the prefix)
        assertTrue(version.length > "grpc.version=".length, "Version string should be longer than just the prefix")
        
        // Test that it doesn't contain "unknown" unless that's all we could get
        assertFalse(version == "grpc.version=unknown", "Version string should not be 'unknown' if we can get the actual version")
    }
}