package com.vit.soniox.keyboard

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class KeyboardHistoryOutboxTest {
    private fun tmp(): File = File.createTempFile("outbox", ".jsonl").also { it.delete() }

    @Test
    fun appendsTrimmedJsonLine() {
        val f = tmp()
        assertTrue(KeyboardHistoryOutbox.append(f, "  olá mundo \n", 1234L))
        val obj = JSONObject(f.readLines().single())
        assertEquals("olá mundo", obj.getString("final_text"))
        assertEquals(1234L, obj.getLong("created_at"))
        f.delete()
    }

    @Test
    fun ignoresBlankText() {
        val f = tmp()
        assertFalse(KeyboardHistoryOutbox.append(f, "   \n", 1L))
        assertFalse(f.exists())
    }

    @Test
    fun capDropsOldest() {
        val f = tmp()
        for (i in 1..7) KeyboardHistoryOutbox.append(f, "t$i", i.toLong(), maxLines = 3)
        val texts = f.readLines().map { JSONObject(it).getString("final_text") }
        assertEquals(listOf("t5", "t6", "t7"), texts)
        f.delete()
    }

    @Test
    fun escapesNewlinesAndQuotes() {
        val f = tmp()
        KeyboardHistoryOutbox.append(f, "a\n\"b\"", 1L)
        assertEquals(1, f.readLines().size)
        assertEquals("a\n\"b\"", JSONObject(f.readLines().single()).getString("final_text"))
        f.delete()
    }

    @Test
    fun neverThrowsOnUnwritablePath() {
        assertFalse(KeyboardHistoryOutbox.append(File("/nonexistent-dir/x/y.jsonl"), "x", 1L))
    }
}
