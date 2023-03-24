package org.feuyeux.grpc

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class UtilsTest {

    @Test
    fun testMatch() {
        val greeting = Utils.match("Hello")
        assertEquals("Thank you very much", greeting)
    }
}