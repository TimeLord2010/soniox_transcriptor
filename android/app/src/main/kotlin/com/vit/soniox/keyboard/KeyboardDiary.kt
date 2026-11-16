package com.vit.soniox.keyboard

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Diário do teclado: últimas linhas de eventos do IME, gravadas em arquivo no
 * `filesDir` para o usuário copiar na tela do app e mandar. Barato (acrescenta
 * uma linha por evento) e NUNCA lança: um defeito do diário não pode derrubar o
 * teclado. O IME e a Activity rodam no mesmo processo, então o arquivo é o
 * ponto de encontro.
 */
object KeyboardDiary {
    const val MAX_LINES = 400
    private const val SLACK = 100
    private const val FILE_NAME = "keyboard_diary.log"

    private var file: File? = null
    private var count = -1
    private val format = SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US)

    @Synchronized
    fun init(context: Context) {
        try {
            if (file == null) file = File(context.applicationContext.filesDir, FILE_NAME)
        } catch (_: Throwable) {
        }
    }

    @Synchronized
    fun log(message: String) {
        try {
            val target = file ?: return
            if (count < 0) count = if (target.exists()) target.readLines().size else 0
            target.appendText("${format.format(Date())} $message\n")
            count++
            if (count > MAX_LINES + SLACK) {
                val kept = trimToLast(target.readLines(), MAX_LINES)
                target.writeText(kept.joinToString("\n", postfix = "\n"))
                count = kept.size
            }
        } catch (_: Throwable) {
        }
    }

    @Synchronized
    fun read(): String = try {
        file?.takeIf { it.exists() }?.readText().orEmpty()
    } catch (_: Throwable) {
        ""
    }

    @Synchronized
    fun clear() {
        try {
            file?.delete()
            count = 0
        } catch (_: Throwable) {
        }
    }

    /** Mantém só as últimas [max] linhas. */
    fun trimToLast(lines: List<String>, max: Int): List<String> =
        if (lines.size <= max) lines else lines.subList(lines.size - max, lines.size)
}
