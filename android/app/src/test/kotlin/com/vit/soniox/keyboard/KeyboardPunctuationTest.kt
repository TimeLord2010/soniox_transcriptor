package com.vit.soniox.keyboard

import org.junit.Assert.assertEquals
import org.junit.Test

class KeyboardPunctuationTest {
    @Test
    fun questionReplacesFinalPeriod() {
        assertEquals(1, KeyboardPunctuation.charsToDropBeforeQuestion("Tudo bem."))
        assertEquals("Tudo bem?", KeyboardPunctuation.appendQuestion("Tudo bem."))
    }

    @Test
    fun questionReplacesPeriodAndTrailingSpaces() {
        assertEquals(2, KeyboardPunctuation.charsToDropBeforeQuestion("Tudo bem. "))
        assertEquals("Tudo bem?", KeyboardPunctuation.appendQuestion("Tudo bem.  "))
    }

    @Test
    fun questionWithoutPeriodJustAppends() {
        assertEquals(0, KeyboardPunctuation.charsToDropBeforeQuestion("Tudo bem"))
        assertEquals(0, KeyboardPunctuation.charsToDropBeforeQuestion("Tudo bem "))
        assertEquals("Tudo bem?", KeyboardPunctuation.appendQuestion("Tudo bem"))
        assertEquals("Ok,?", KeyboardPunctuation.appendQuestion("Ok,"))
    }

    @Test
    fun questionKeepsEllipsis() {
        assertEquals(0, KeyboardPunctuation.charsToDropBeforeQuestion("Será..."))
        assertEquals("Será...?", KeyboardPunctuation.appendQuestion("Será..."))
    }

    @Test
    fun questionOnEmptyField() {
        assertEquals(0, KeyboardPunctuation.charsToDropBeforeQuestion(null))
        assertEquals(0, KeyboardPunctuation.charsToDropBeforeQuestion(""))
        assertEquals(1, KeyboardPunctuation.charsToDropBeforeQuestion("."))
        assertEquals("?", KeyboardPunctuation.appendQuestion(""))
    }

    @Test
    fun atGluesNextFinal() {
        assertEquals("gmail.com", KeyboardPunctuation.glueAfterAt(" gmail.com"))
        assertEquals("", KeyboardPunctuation.glueAfterAt("  "))
    }

    @Test
    fun historyEditRewritesAccumulated() {
        val got = mutableListOf<String>()
        val b = SessionHistoryBuffer { got.add(it) }
        b.onFinal("Tudo bem.")
        b.edit(KeyboardPunctuation::appendQuestion)
        b.flush()
        assertEquals(listOf("Tudo bem?"), got)
    }
}
