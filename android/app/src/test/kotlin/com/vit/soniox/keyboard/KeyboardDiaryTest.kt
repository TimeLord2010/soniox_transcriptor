package com.vit.soniox.keyboard

import org.junit.Assert.assertEquals
import org.junit.Test

class KeyboardDiaryTest {
    @Test
    fun trimKeepsLastLines() {
        val lines = (1..10).map { "l$it" }
        assertEquals(listOf("l8", "l9", "l10"), KeyboardDiary.trimToLast(lines, 3))
    }

    @Test
    fun trimKeepsEverythingWhenShort() {
        assertEquals(listOf("a", "b"), KeyboardDiary.trimToLast(listOf("a", "b"), 5))
    }
}
