package com.vit.soniox.keyboard

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * O que o app Flutter publica para o teclado, em um único JSON
 * (`flutter.keyboard.session` nas preferências compartilhadas do app).
 *
 * O app é a fonte da verdade: perfil ativo, chave, idiomas, termos, contexto e
 * tradução vivem lá. O teclado NÃO lê as chaves internas de perfil
 * (`profile.<id>.*`) — elas são detalhe de implementação do Dart e mudariam o
 * formato do teclado junto. Um blob só, versionado, é o contrato.
 */
data class KeyboardSession(
    val apiKey: String,
    val languages: List<String>,
    val contextText: String,
    val terms: List<String>,
    val translationTarget: String?,
    /** Modelo escolhido no app; blob antigo (sem o campo) cai no [MODEL]. */
    val model: String,
) {
    /** Sem chave não há sessão: o teclado só pode avisar o usuário. */
    val hasApiKey: Boolean get() = apiKey.isNotBlank()

    val translates: Boolean get() = translationTarget != null

    /**
     * Config enviado no `start` do WebSocket: o MESMO contrato de
     * `buildSessionConfig` no Dart (`lib/modules/session_config.dart`).
     *
     * Diferença deliberada: diarização sempre desligada. O teclado escreve em
     * um campo de texto, onde o rótulo "Falante N:" não tem para onde ir.
     */
    fun toSonioxConfig(): JSONObject {
        // A chave NÃO vai no `start`: autentica a CONEXÃO (header do upgrade).
        // O Soniox recusa conexão sem chave a partir de 15/01/2027.
        val config = JSONObject()
            .put("model", model)
            .put("enable_speaker_diarization", false)
            .put("language_hints", JSONArray(languages))
            .put("language_hints_strict", languages.isNotEmpty())
            .put("enable_language_identification", false)
            .put("enable_endpoint_detection", false)
            .put("audio_format", AUDIO_FORMAT)
            .put("sample_rate", SAMPLE_RATE)
            .put("num_channels", NUM_CHANNELS)

        if (contextText.isNotBlank() || terms.isNotEmpty()) {
            val context = JSONObject()
            if (contextText.isNotBlank()) context.put("text", contextText)
            if (terms.isNotEmpty()) context.put("terms", JSONArray(terms))
            config.put("context", context)
        }

        // One-way: o Soniox detecta o idioma falado e traduz para o alvo — não
        // existe campo de idioma de origem.
        translationTarget?.let { target ->
            config.put(
                "translation",
                JSONObject().put("type", "one_way").put("target_language", target),
            )
        }

        return config
    }

    companion object {
        /** Só para blob antigo/sem campo; o app manda o modelo do perfil. */
        const val MODEL = "stt-rt-v5"
        const val AUDIO_FORMAT = "pcm_s16le"
        const val SAMPLE_RATE = 16000
        const val NUM_CHANNELS = 1

        /** Preferências do plugin shared_preferences do Flutter. */
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val PREFS_KEY = "flutter.keyboard.session"

        fun load(context: Context): KeyboardSession {
            val raw = context
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(PREFS_KEY, null)
                ?: return empty()
            return fromJson(raw)
        }

        fun empty() = KeyboardSession("", emptyList(), "", emptyList(), null, MODEL)

        fun fromJson(raw: String): KeyboardSession = try {
            val object0 = JSONObject(raw)
            KeyboardSession(
                apiKey = object0.optString("api_key", ""),
                languages = object0.optJSONArray("languages").toStringList(),
                contextText = object0.optString("context_text", ""),
                terms = object0.optJSONArray("terms").toStringList(),
                translationTarget = if (object0.isNull("translation_target")) {
                    null
                } else {
                    object0.optString("translation_target", "").ifBlank { null }
                },
                // Blob da versão 1 não tem modelo: o teclado abre com o padrão.
                model = object0.optString("model", "").ifBlank { MODEL },
            )
        } catch (e: Exception) {
            // Blob corrompido (versão antiga, escrita interrompida) equivale a
            // "sem configuração" em vez de derrubar o teclado.
            empty()
        }

        private fun JSONArray?.toStringList(): List<String> {
            if (this == null) return emptyList()
            return (0 until length()).mapNotNull { index ->
                optString(index, "").ifBlank { null }
            }
        }
    }
}
