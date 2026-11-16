package com.vit.soniox.keyboard

import android.content.Context
import org.json.JSONObject
import java.io.File

/**
 * Caixa de saída do histórico: o teclado (Kotlin) não abre o SQLite do app
 * (duas bibliotecas SQLite no mesmo arquivo arriscam travar/corromper). Ele só
 * acrescenta uma linha JSON por ditado em `keyboard_history_outbox.jsonl`, no
 * `filesDir`; o app (Dart) renomeia o arquivo, importa as linhas para o
 * histórico e apaga. NUNCA lança: falha aqui não pode derrubar o teclado.
 */
object KeyboardHistoryOutbox {
    const val FILE_NAME = "keyboard_history_outbox.jsonl"
    const val MAX_LINES = 200

    private var file: File? = null

    @Synchronized
    fun init(context: Context) {
        try {
            if (file == null) file = File(context.applicationContext.filesDir, FILE_NAME)
        } catch (_: Throwable) {
        }
    }

    /** Enfileira o texto de um ditado; ignora texto vazio. */
    fun enqueue(text: String, createdAtMs: Long = System.currentTimeMillis()) {
        val target = file ?: return
        if (append(target, text, createdAtMs)) {
            KeyboardDiary.log("history queued (${text.trim().length} chars)")
        }
    }

    /** Acrescenta a linha em [target]; devolve se algo foi gravado. */
    @Synchronized
    internal fun append(target: File, text: String, createdAtMs: Long, maxLines: Int = MAX_LINES): Boolean {
        return try {
            val trimmed = text.trim()
            if (trimmed.isEmpty()) return false
            val line = JSONObject().put("final_text", trimmed).put("created_at", createdAtMs).toString()
            target.appendText(line + "\n")
            val lines = target.readLines()
            if (lines.size > maxLines) {
                val kept = lines.subList(lines.size - maxLines, lines.size)
                target.writeText(kept.joinToString("\n", postfix = "\n"))
            }
            true
        } catch (_: Throwable) {
            false
        }
    }
}
