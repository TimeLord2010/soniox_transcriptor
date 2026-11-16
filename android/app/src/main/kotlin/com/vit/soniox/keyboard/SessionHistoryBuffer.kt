package com.vit.soniox.keyboard

/**
 * Texto final de UMA sessão de ditado, a caminho do histórico. [flush] entrega
 * o acumulado uma única vez (pega e zera), então `finished` repetido ou o
 * `onDestroy` não duplicam. Independe de o campo ter aceitado o texto.
 */
class SessionHistoryBuffer(private val enqueue: (String) -> Unit) {
    private val text = StringBuilder()

    @Synchronized
    fun onFinal(part: String) {
        text.append(part)
    }

    fun flush() {
        val taken = synchronized(this) {
            val s = text.toString()
            text.setLength(0)
            s
        }
        if (taken.isNotBlank()) enqueue(taken)
    }
}
