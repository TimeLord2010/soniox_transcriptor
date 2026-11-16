package com.vit.soniox.keyboard

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Caixa de saída do histórico: o teclado (Kotlin) não abre o SQLite do app. Cada
 * ditado vira UM arquivo `<createdAtMs>-<uuid>.json` em `filesDir/keyboard_history/`,
 * escrito em `.tmp` e renomeado (atômico): o app (Dart) só lê `*.json`, importa e
 * apaga cada um, sem corrida com o teclado. NUNCA lança: falha aqui não pode
 * derrubar o teclado.
 */
object KeyboardHistoryOutbox {
    const val DIR_NAME = "keyboard_history"
    const val MAX_FILES = 200
    private const val STALE_TMP_MS = 60_000L

    private var dir: File? = null

    @Synchronized
    fun init(context: Context) {
        try {
            if (dir == null) dir = File(context.applicationContext.filesDir, DIR_NAME)
        } catch (_: Throwable) {
        }
    }

    /** Enfileira o texto de um ditado; ignora texto vazio. */
    fun enqueue(text: String, createdAtMs: Long = System.currentTimeMillis()) {
        val target = dir ?: return
        if (append(target, text, createdAtMs)) {
            KeyboardDiary.log("history queued (${text.trim().length} chars)")
        }
    }

    /** Grava um arquivo em [target]; devolve se algo foi gravado. */
    @Synchronized
    internal fun append(
        target: File,
        text: String,
        createdAtMs: Long,
        maxFiles: Int = MAX_FILES,
        nowMs: Long = System.currentTimeMillis(),
    ): Boolean {
        return try {
            val trimmed = text.trim()
            if (trimmed.isEmpty()) return false
            target.mkdirs()
            val base = "$createdAtMs-${UUID.randomUUID()}"
            val tmp = File(target, "$base.tmp")
            tmp.writeText(JSONObject().put("final_text", trimmed).put("created_at", createdAtMs).toString())
            if (!tmp.renameTo(File(target, "$base.json"))) {
                tmp.delete()
                return false
            }
            cleanup(target, maxFiles, nowMs)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun cleanup(target: File, maxFiles: Int, nowMs: Long) {
        try {
            val files = target.listFiles() ?: return
            files.filter { it.name.endsWith(".tmp") && nowMs - it.lastModified() > STALE_TMP_MS }
                .forEach { it.delete() }
            val json = files.filter { it.name.endsWith(".json") }.sortedBy { it.name }
            if (json.size > maxFiles) json.take(json.size - maxFiles).forEach { it.delete() }
        } catch (_: Throwable) {
        }
    }
}
