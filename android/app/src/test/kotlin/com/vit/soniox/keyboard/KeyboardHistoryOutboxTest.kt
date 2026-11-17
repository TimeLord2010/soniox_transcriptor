package com.vit.soniox.keyboard

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

class KeyboardHistoryOutboxTest {
    private fun tmpDir(): File = Files.createTempDirectory("outbox").toFile()
    private fun jsons(d: File) = d.listFiles()!!.filter { it.name.endsWith(".json") }.sortedBy { it.name }

    @Test
    fun writesOneJsonFileAndNoTmp() {
        val d = tmpDir()
        assertTrue(KeyboardHistoryOutbox.append(d, "  olá mundo \n", 1234L))
        assertTrue(d.listFiles()!!.none { it.name.endsWith(".tmp") })
        val f = jsons(d).single()
        assertTrue(f.name.startsWith("1234-"))
        val obj = JSONObject(f.readText())
        assertEquals("olá mundo", obj.getString("final_text"))
        assertEquals(1234L, obj.getLong("created_at"))
        d.deleteRecursively()
    }

    @Test
    fun ignoresBlankText() {
        val d = tmpDir()
        assertFalse(KeyboardHistoryOutbox.append(d, "   \n", 1L))
        assertEquals(0, d.listFiles()!!.size)
        d.deleteRecursively()
    }

    @Test
    fun writesClientReferenceIdAndKeepsEmptyTextOnlyWithIt() {
        val d = tmpDir()
        assertTrue(KeyboardHistoryOutbox.append(d, "oi", 1L, clientReferenceId = "ref-1"))
        assertTrue(KeyboardHistoryOutbox.append(d, "", 2L, clientReferenceId = "ref-2"))
        assertFalse(KeyboardHistoryOutbox.append(d, "", 3L))
        val objs = jsons(d).map { JSONObject(it.readText()) }
        assertEquals("ref-1", objs[0].getString("client_reference_id"))
        assertEquals("ref-2", objs[1].getString("client_reference_id"))
        assertEquals("", objs[1].getString("final_text"))
        d.deleteRecursively()
    }

    @Test
    fun capDeletesOldest() {
        val d = tmpDir()
        for (i in 1..7) KeyboardHistoryOutbox.append(d, "t$i", i.toLong(), maxFiles = 3)
        val texts = jsons(d).map { JSONObject(it.readText()).getString("final_text") }
        assertEquals(listOf("t5", "t6", "t7"), texts)
        d.deleteRecursively()
    }

    @Test
    fun deletesStaleTmpOnly() {
        val d = tmpDir()
        val old = File(d, "1-a.tmp").apply { writeText("x"); setLastModified(0L) }
        val fresh = File(d, "2-b.tmp").apply { writeText("x") }
        KeyboardHistoryOutbox.append(d, "t", 3L)
        assertFalse(old.exists())
        assertTrue(fresh.exists())
        d.deleteRecursively()
    }

    @Test
    fun keepsNewlinesAndQuotes() {
        val d = tmpDir()
        KeyboardHistoryOutbox.append(d, "a\n\"b\"", 1L)
        assertEquals("a\n\"b\"", JSONObject(jsons(d).single().readText()).getString("final_text"))
        d.deleteRecursively()
    }

    @Test
    fun neverThrowsOnUnwritablePath() {
        assertFalse(KeyboardHistoryOutbox.append(File("/proc/nonexistent/x"), "x", 1L))
    }
}
