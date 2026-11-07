package com.vit.soniox.keyboard

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Contrato do teclado com o Soniox: o JSON de `start` tem que ser o mesmo que o
 * app monta em `buildSessionConfig` (`lib/modules/session_config.dart`).
 *
 * Cada parâmetro opcional é conferido nos dois sentidos: presente quando
 * ligado e AUSENTE quando desligado. Campo a mais no payload é erro silencioso
 * (o servidor aceita e o comportamento muda sem ninguém ver).
 */
class KeyboardSessionTest {

    private fun session(
        apiKey: String = "chave",
        languages: List<String> = listOf("pt"),
        context: String = "",
        terms: List<String> = emptyList(),
        translation: String? = null,
    ) = KeyboardSession(apiKey, languages, context, terms, translation)

    @Test
    fun `payload base espelha o contrato do app`() {
        val config = session().toSonioxConfig()
        // A chave autentica a conexão (header), nunca o primeiro frame.
        assertFalse(config.has("api_key"))
        assertEquals("stt-rt-v5", config.getString("model"))
        assertEquals("pcm_s16le", config.getString("audio_format"))
        assertEquals(16000, config.getInt("sample_rate"))
        assertEquals(1, config.getInt("num_channels"))
        assertEquals("[\"pt\"]", config.getJSONArray("language_hints").toString())
        assertTrue(config.getBoolean("language_hints_strict"))
        // O teclado escreve em campo de texto: rótulo de falante não entra.
        assertFalse(config.getBoolean("enable_speaker_diarization"))
        assertFalse(config.getBoolean("enable_endpoint_detection"))
        assertFalse(config.has("context"))
        assertFalse(config.has("translation"))
    }

    @Test
    fun `sem idiomas o strict desliga`() {
        val config = session(languages = emptyList()).toSonioxConfig()
        assertEquals(0, config.getJSONArray("language_hints").length())
        assertFalse(config.getBoolean("language_hints_strict"))
    }

    @Test
    fun `contexto entra so quando ha conteudo`() {
        assertFalse(session().toSonioxConfig().has("context"))

        val onlyTerms = session(terms = listOf("Soniox", "LEIA")).toSonioxConfig()
        val contexto = onlyTerms.getJSONObject("context")
        assertFalse(contexto.has("text"))
        assertEquals("[\"Soniox\",\"LEIA\"]", contexto.getJSONArray("terms").toString())

        val onlyText = session(context = "reunião sobre o app").toSonioxConfig()
        assertEquals("reunião sobre o app", onlyText.getJSONObject("context").getString("text"))
    }

    @Test
    fun `traducao one-way nao tem idioma de origem`() {
        val config = session(translation = "en").toSonioxConfig()
        val translation = config.getJSONObject("translation")
        assertEquals("one_way", translation.getString("type"))
        assertEquals("en", translation.getString("target_language"))
        assertFalse(translation.has("source_language"))
    }

    @Test
    fun `blob do app e lido pelo formato publicado`() {
        val raw = """
            {"version":1,"api_key":"k","languages":["pt","en"],
             "context_text":"ctx","terms":["LEIA"],"translation_target":"en"}
        """.trimIndent()
        val parsed = KeyboardSession.fromJson(raw)
        assertEquals("k", parsed.apiKey)
        assertEquals(listOf("pt", "en"), parsed.languages)
        assertEquals("ctx", parsed.contextText)
        assertEquals(listOf("LEIA"), parsed.terms)
        assertEquals("en", parsed.translationTarget)
        assertTrue(parsed.translates)
    }

    @Test
    fun `traducao desligada e blob quebrado viram sessao sem config`() {
        val off = KeyboardSession.fromJson("""{"api_key":"k","translation_target":null}""")
        assertNull(off.translationTarget)
        assertFalse(off.translates)

        // Blob corrompido não derruba o teclado: equivale a "sem configuração".
        val broken = KeyboardSession.fromJson("{isso não é json")
        assertEquals("", broken.apiKey)
        assertFalse(broken.hasApiKey)
    }

    @Test
    fun `json gerado e json valido e sem chave vazia o teclado avisa`() {
        val config: JSONObject = session().toSonioxConfig()
        assertFalse(config.has("api_key"))
        assertFalse(KeyboardSession("", emptyList(), "", emptyList(), null).hasApiKey)
    }
}
