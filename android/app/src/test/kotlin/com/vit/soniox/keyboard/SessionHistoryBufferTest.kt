package com.vit.soniox.keyboard

import org.junit.Assert.assertEquals
import org.junit.Test

class SessionHistoryBufferTest {
    @Test
    fun finalThenFlushEnqueuesOnce() {
        val got = mutableListOf<String>()
        val b = SessionHistoryBuffer { got.add(it) }
        b.onFinal("a")
        b.flush()
        b.flush()
        assertEquals(listOf("a"), got)
    }

    @Test
    fun concatenatesFinals() {
        val got = mutableListOf<String>()
        val b = SessionHistoryBuffer { got.add(it) }
        b.onFinal("olá ")
        b.onFinal("mundo")
        b.flush()
        assertEquals(listOf("olá mundo"), got)
    }

    @Test
    fun emptyFlushEnqueuesNothingAndLateFinalIsSeparate() {
        val got = mutableListOf<String>()
        val b = SessionHistoryBuffer { got.add(it) }
        b.flush()
        b.onFinal("tarde")
        b.flush()
        assertEquals(listOf("tarde"), got)
    }
}
