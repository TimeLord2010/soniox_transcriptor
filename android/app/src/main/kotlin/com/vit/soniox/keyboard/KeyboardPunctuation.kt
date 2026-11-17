package com.vit.soniox.keyboard

/**
 * Regras das teclas de pontuação do teclado (`@` e `?`), separadas da UI para
 * serem testáveis sem `InputConnection`.
 */
object KeyboardPunctuation {
    const val AT = "@"
    const val QUESTION = "?"

    /**
     * Quantos caracteres apagar antes do cursor para inserir o `?`: espaços no
     * fim e, logo antes deles, um ponto final ("Tudo bem." → "Tudo bem?").
     * Reticências ficam ("Será..." → "Será...?"). Sem ponto, nada é apagado,
     * nem os espaços — o `?` só substitui o ponto que o Soniox pôs.
     */
    fun charsToDropBeforeQuestion(before: CharSequence?): Int {
        if (before.isNullOrEmpty()) return 0
        var end = before.length
        while (end > 0 && before[end - 1].isWhitespace()) end--
        if (end == 0 || before[end - 1] != '.') return 0
        if (end >= 2 && before[end - 2] == '.') return 0
        return before.length - end + 1
    }

    /** O mesmo que o campo recebe, aplicado a um texto inteiro (histórico). */
    fun appendQuestion(text: String): String =
        text.dropLast(charsToDropBeforeQuestion(text)) + QUESTION

    /**
     * Depois do `@`, o próximo final do ditado vem com espaço na frente
     * (" gmail.com"); colado fica "fulano@gmail.com".
     */
    fun glueAfterAt(text: String): String = text.trimStart()
}
