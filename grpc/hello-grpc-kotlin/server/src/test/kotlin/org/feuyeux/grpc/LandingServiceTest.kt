package org.feuyeux.grpc

import org.apache.logging.log4j.kotlin.logger
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

class LandingServiceTest {
    private val log = logger()
    val svc: LandingService = LandingService(null)

    @Test
    fun test() {
        val result = svc.buildResult("1")
        val idx = result.kvMap["idx"]
        log.info("result=${idx}")
        assertEquals(idx, "1")
    }
}