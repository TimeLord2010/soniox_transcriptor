package com.vit.soniox.keyboard

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString.Companion.toByteString
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Uma sessão de ditado: microfone → PCM 16 kHz → WebSocket da Soniox → texto.
 *
 * O protocolo é o mesmo que o app usa pelo pacote `vit_soniox`: config em JSON
 * no primeiro frame de texto, áudio em frames binários, e o servidor devolve
 * `tokens` com `is_final`. Aqui a sessão é escrita em Kotlin porque um teclado
 * (InputMethodService) não tem onde hospedar o motor do Flutter.
 *
 * Toda atualização é entregue na thread principal: quem consome escreve no
 * campo de texto do app em foco (`InputConnection`), que só aceita isso na main.
 */
class DictationSession(
    private val context: Context,
    private val session: KeyboardSession,
    private val listener: (Update) -> Unit,
) {
    /** Estado observável da sessão, sempre emitido na thread principal. */
    data class Update(
        val preview: String? = null,
        val finalText: String? = null,
        val error: String? = null,
        val connected: Boolean = false,
        val finished: Boolean = false,
        /** Fala que o Soniox transcreveu sem traduzir: já está no idioma alvo. */
        val nothingToTranslate: Boolean = false,
    )

    private val main = Handler(Looper.getMainLooper())
    private val stopper = AtomicBoolean(false)
    private val audioRunning = AtomicBoolean(false)
    private var socket: WebSocket? = null
    private var recorder: AudioRecord? = null
    private var audioThread: Thread? = null

    private val client = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    // MARK: Ciclo de vida

    fun start() {
        Log.d(TAG, "start: chave=${session.hasApiKey} idiomas=${session.languages} traducao=${session.translationTarget}")
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "start: RECORD_AUDIO negado")
            emit(Update(error = "Permissão de microfone não concedida. Abra o app Soniox e libere o microfone."))
            return
        }
        val request = Request.Builder().url(URL).build()
        socket = client.newWebSocket(request, SocketListener())
    }

    /** Encerra o ditado, mas espera o Soniox finalizar o que já foi falado. */
    fun stop() {
        if (stopper.getAndSet(true)) return
        stopAudio()
        val open = socket
        if (open == null) {
            emit(Update(finished = true))
            return
        }
        // `finalize` força os tokens pendentes a virarem finais; sem esperar por
        // eles o fim da frase falada se perde.
        open.send(FINALIZE)
        main.postDelayed({
            open.close(NORMAL_CLOSURE, "bye")
            emit(Update(finished = true))
        }, FINALIZE_GRACE_MS)
    }

    fun release() {
        stopper.set(true)
        stopAudio()
        socket?.close(NORMAL_CLOSURE, "release")
        socket = null
        client.dispatcher.executorService.shutdown()
    }

    // MARK: Áudio

    @SuppressLint("MissingPermission")
    private fun startAudio() {
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer <= 0) {
            emit(Update(error = "O aparelho não aceita PCM 16 kHz mono."))
            socket?.close(NORMAL_CLOSURE, "no pcm")
            return
        }
        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuffer * 2, CHUNK_BYTES * 2),
            )
        } catch (e: Exception) {
            emit(Update(error = "Não consegui abrir o microfone: ${e.message ?: e.javaClass.simpleName}"))
            socket?.close(NORMAL_CLOSURE, "no recorder")
            return
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            emit(Update(error = "Microfone indisponível (outro app está usando?)."))
            socket?.close(NORMAL_CLOSURE, "no recorder")
            return
        }
        recorder = record
        audioRunning.set(true)
        record.startRecording()
        Log.d(TAG, "microfone aberto: ${record.sampleRate}Hz chunk=${CHUNK_BYTES}B")

        audioThread = Thread({
            val buffer = ByteArray(CHUNK_BYTES)
            while (audioRunning.get() && !stopper.get()) {
                val read = try {
                    record.read(buffer, 0, buffer.size)
                } catch (e: Exception) {
                    -1
                }
                if (read == 0) continue
                if (read < 0) {
                    // Parada normal: o recorder foi fechado por `stopAudio`, então
                    // `read` falha de propósito — não é erro para o usuário ver.
                    if (!stopper.get() && audioRunning.get()) {
                        emit(Update(error = "A captura de áudio parou."))
                        main.post { stop() }
                    }
                    break
                }
                socket?.send(buffer.toByteString(0, read))
            }
        }, "soniox-audio").also { it.start() }
    }

    private fun stopAudio() {
        audioRunning.set(false)
        audioThread?.join(300)
        audioThread = null
        recorder?.let { record ->
            try {
                record.stop()
            } catch (e: IllegalStateException) {
                // Já parado: nada a fazer.
            }
            record.release()
        }
        recorder = null
    }

    // MARK: WebSocket

    private inner class SocketListener : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            Log.d(TAG, "ws aberto: enviando config e abrindo microfone")
            webSocket.send(session.toSonioxConfig().toString())
            emit(Update(connected = true))
            startAudio()
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            Log.d(TAG, "ws mensagem: ${text.take(160)}")
            handleMessage(text)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            Log.w(TAG, "ws falhou: ${t.message} http=${response?.code}")
            stopAudio()
            val code = response?.code
            emit(
                Update(
                    error = if (code != null) {
                        "Sem conexão com o Soniox (HTTP $code)."
                    } else {
                        "Sem conexão com o Soniox: ${t.message ?: t.javaClass.simpleName}"
                    },
                ),
            )
            emit(Update(finished = true))
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            stopAudio()
            emit(Update(finished = true))
        }
    }

    private fun handleMessage(text: String) {
        val payload = try {
            JSONObject(text)
        } catch (e: Exception) {
            emit(Update(error = "Resposta ilegível do Soniox."))
            return
        }

        // Erro vem como `error_code` (e `tokens` vazio): conferir antes dos
        // tokens, como no pacote.
        if (payload.has("error_code")) {
            val code = payload.optString("error_code", "?")
            val message = payload.optString("error_message", payload.optString("error_type", ""))
            emit(Update(error = "Erro Soniox $code: $message"))
            main.post { stop() }
            return
        }

        val tokens = payload.optJSONArray("tokens") ?: return
        val finalText = StringBuilder()
        val preview = StringBuilder()
        var nothingToTranslate = false

        for (index in 0 until tokens.length()) {
            val token = tokens.optJSONObject(index) ?: continue
            val word = token.optString("text", "")
            // Marcadores de controle do protocolo (`<end>` de fim de fala,
            // `<fin>` que fecha o `finalize`) não são conteúdo: o `<fin>` era
            // digitado no campo ao tocar em "parar".
            if (word.isEmpty() || CONTROL_TOKEN.matches(word)) continue
            val isFinal = token.optBoolean("is_final", false)
            val status = token.optString("translation_status", "")

            if (session.translates) {
                // Com tradução ligada o texto vai para o campo traduzido —
                // juntar original e tradução no mesmo campo duplicaria a frase.
                when (status) {
                    "translation" -> (if (isFinal) finalText else preview).append(word)
                    "none" -> nothingToTranslate = true
                    else -> Unit
                }
            } else {
                (if (isFinal) finalText else preview).append(word)
            }
        }

        if (nothingToTranslate) emit(Update(nothingToTranslate = true))
        // A prévia é sempre o texto não final INTEIRO da mensagem (o servidor
        // reescreve esses tokens a cada evento), enquanto os finais são deltas.
        emit(Update(preview = preview.toString()))
        if (finalText.isNotEmpty()) emit(Update(finalText = finalText.toString()))
    }

    private fun emit(update: Update) {
        main.post { listener(update) }
    }

    companion object {
        private const val TAG = "SonioxDictation"
        private const val URL = "wss://stt-rt.soniox.com/transcribe-websocket"
        private const val SAMPLE_RATE = KeyboardSession.SAMPLE_RATE
        private const val CHUNK_MS = 100
        private const val CHUNK_BYTES = SAMPLE_RATE * 2 * CHUNK_MS / 1000
        private const val FINALIZE = """{"type":"finalize"}"""
        /** Marcadores do protocolo (`<end>`, `<fin>`) — nunca texto do ditado. */
        private val CONTROL_TOKEN = Regex("^<[a-z0-9_]+>$")
        private const val FINALIZE_GRACE_MS = 1500L
        private const val NORMAL_CLOSURE = 1000
    }
}
