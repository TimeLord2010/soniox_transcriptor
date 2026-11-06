package com.vit.soniox.keyboard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Teclado de ditado da Soniox: microfone → texto no campo do app em foco.
 *
 * É um `InputMethodService` nativo (Kotlin), não Flutter: um teclado é um
 * service com janela própria, e o motor do Flutter precisa de uma Activity para
 * desenhar — não há IME Flutter de verdade. O contrato com o app (chave, idioma,
 * termos, contexto, tradução) chega pelo JSON que o app publica nas
 * preferências compartilhadas; ver [KeyboardSession].
 *
 * Nenhuma tecla de letra: o teclado é de DITADO. O botão "abc" troca para o
 * teclado normal do aparelho, que continua sendo o caminho para digitar.
 */
class SonioxKeyboardService : InputMethodService() {

    private enum class State { Idle, Connecting, Listening, Finishing, Error }

    private lateinit var root: LinearLayout
    private lateinit var statusView: TextView
    private lateinit var previewView: TextView
    private lateinit var micView: TextView
    private lateinit var spaceView: TextView
    private lateinit var backspaceView: TextView
    private lateinit var enterView: TextView

    private var state = State.Idle
    private var statusOverride: String? = null
    private var preview = ""
    private var nothingToTranslate = false
    private var session: KeyboardSession = KeyboardSession.empty()
    private var dictation: DictationSession? = null
    private var foreground = false

    /** Recuo inferior (px) da barra do sistema já aplicado ao root. */
    private var insetBottomPx = 0

    private val handler = Handler(Looper.getMainLooper())
    private val density by lazy { resources.displayMetrics.density }
    private val isNight by lazy {
        (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
    }

    // MARK: Ciclo do teclado

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "service onCreate pid=${android.os.Process.myPid()}")
    }

    /**
     * Teclado virtual some quando o sistema acha que existe teclado físico
     * (padrão em emulador e com teclado Bluetooth pareado). Um teclado de
     * DITADO não tem tecla física equivalente: escondê-lo por isso sumiria com
     * a única função dele, então ele aparece sempre.
     */
    override fun onEvaluateInputViewShown(): Boolean {
        Log.d(TAG, "onEvaluateInputViewShown -> true (teclado de ditado)")
        return true
    }

    override fun onShowInputRequested(flags: Int, force: Boolean): Boolean {
        val requested = super.onShowInputRequested(flags, force)
        Log.d(TAG, "onShowInputRequested flags=$flags force=$force -> $requested")
        return requested
    }

    override fun onWindowShown() {
        super.onWindowShown()
        Log.d(TAG, "onWindowShown")
        // A barra do sistema pode ter mudado enquanto o teclado estava oculto.
        refreshWindowInsets()
    }

    override fun onCreateInputView(): View {
        session = KeyboardSession.load(this)
        Log.d(TAG, "onCreateInputView: chave=${session.hasApiKey} idiomas=${session.languages}")
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))
            setBackgroundColor(if (isNight) NIGHT_BACKGROUND else LIGHT_BACKGROUND)
        }

        root.addView(topRow())
        root.addView(previewLine())
        root.addView(micRow())
        root.addView(spaceRow())

        applyWindowInsets()
        render()
        return root
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        Log.d(TAG, "onStartInputView: inputType=${info?.inputType}")
        // O perfil pode ter mudado com o app aberto: relê a config a cada vez
        // que o teclado aparece, em vez de confiar no que foi lido no onCreate.
        session = KeyboardSession.load(this)
        refreshWindowInsets()
        if (state == State.Idle) render()
    }

    override fun onFinishInput() {
        // Campo perdeu o foco: parar de gravar. Microfone aberto no escuro é
        // exatamente o que não pode acontecer num teclado.
        stopDictation()
        super.onFinishInput()
    }

    override fun onWindowHidden() {
        stopDictation()
        super.onWindowHidden()
    }

    override fun onDestroy() {
        dictation?.release()
        dictation = null
        stopForegroundQuietly()
        super.onDestroy()
    }

    // MARK: Views

    private fun topRow(): View = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL

        statusView = TextView(context).apply {
            textSize = 13f
            setTextColor(secondaryColor())
            maxLines = 2
        }
        addView(statusView, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

        addView(smallButton("abc") { switchToLetterKeyboard() })
        addView(smallButton("⌄") { requestHideSelf(0) })
    }

    private fun previewLine(): View = TextView(this).apply {
        previewView = this
        textSize = 15f
        setTextColor(primaryColor())
        maxLines = 2
        setPadding(0, dp(6), 0, dp(6))
        ellipsize = android.text.TextUtils.TruncateAt.END
    }

    private fun micRow(): View = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL

        backspaceView = squareButton("⌫") { deleteBackward() }
        addView(backspaceView, LinearLayout.LayoutParams(dp(56), dp(56)))

        micView = TextView(context).apply {
            gravity = Gravity.CENTER
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            setOnClickListener { toggleDictation() }
            isClickable = true
            isFocusable = true
            contentDescription = "Gravar ditado"
        }
        addView(
            micView,
            LinearLayout.LayoutParams(0, dp(64), 1f).apply {
                marginStart = dp(10)
                marginEnd = dp(10)
            },
        )

        enterView = squareButton("↵") { commitEnter() }
        addView(enterView, LinearLayout.LayoutParams(dp(56), dp(56)))
    }

    private fun spaceRow(): View = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        setPadding(0, dp(8), 0, 0)

        spaceView = TextView(context).apply {
            gravity = Gravity.CENTER
            text = "espaço"
            textSize = 14f
            setTextColor(primaryColor())
            background = rounded(if (isNight) NIGHT_KEY else LIGHT_KEY, dp(12))
            setOnClickListener { commitSpace() }
            isClickable = true
        }
        addView(spaceView, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(44)))
    }

    private fun smallButton(label: String, action: () -> Unit): TextView =
        TextView(this).apply {
            text = label
            textSize = 13f
            gravity = Gravity.CENTER
            setTextColor(secondaryColor())
            setPadding(dp(12), dp(6), dp(12), dp(6))
            setOnClickListener { action() }
            isClickable = true
            contentDescription = label
        }

    private fun squareButton(label: String, action: () -> Unit): TextView =
        TextView(this).apply {
            text = label
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(primaryColor())
            background = rounded(if (isNight) NIGHT_KEY else LIGHT_KEY, dp(12))
            setOnClickListener { action() }
            isClickable = true
            contentDescription = label
        }

    /**
     * Recuo inferior: a barra de navegação/gestos do sistema — onde ficam os
     * botões "ocultar teclado" e "trocar de teclado" — é desenhada SOBRE a
     * janela do teclado. O inset tem que ser lido no `decorView` da janela do
     * IME: o `InputMethodService` consome os insets no caminho até a input
     * view, então um listener no `root` recebe zero e o conteúdo fica atrás
     * dos botões do sistema (era o defeito relatado). O listener do decor
     * também é o único que recebe a mudança quando a barra aparece/some.
     */
    private fun applyWindowInsets() {
        val decor = window?.window?.decorView ?: return
        decor.setOnApplyWindowInsetsListener { _, insets ->
            updateBottomInset(insets)
            insets
        }
        decor.post { decor.rootWindowInsets?.let(::updateBottomInset) }
    }

    /** Relê os insets da janela (rotação, barra de navegação trocada). */
    private fun refreshWindowInsets() {
        val decor = window?.window?.decorView ?: return
        decor.rootWindowInsets?.let(::updateBottomInset)
    }

    private fun updateBottomInset(insets: WindowInsets) {
        val bottom = bottomInset(insets)
        Log.d(TAG, "insets: recuo inferior=${bottom}px (${bottom / density}dp)")
        if (bottom == insetBottomPx) return
        insetBottomPx = bottom
        root.setPadding(dp(12), dp(8), dp(12), dp(8) + bottom)
    }

    /**
     * Altura (px) da barra do sistema na base da janela do teclado.
     *
     * A barra onde o sistema desenha "ocultar teclado" e "trocar de teclado" é
     * a `navigationBars`. `systemGestures` é a área de exclusão de gesto, maior
     * que a barra: só serve de reserva quando a barra se declara com altura
     * zero — que é justamente o caso em que o conteúdo ficaria atrás dos
     * botões do sistema.
     */
    private fun bottomInset(insets: WindowInsets): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            @Suppress("DEPRECATION")
            return insets.systemWindowInsetBottom
        }
        val bars = insets.getInsets(WindowInsets.Type.navigationBars()).bottom
        val gestures = insets.getInsets(WindowInsets.Type.systemGestures()).bottom
        Log.d(TAG, "insets: navigationBars=${bars}px systemGestures=${gestures}px")
        if (bars > 0) return bars
        if (gestures > 0) return gestures
        // Aparelho que não reporta inset nenhum mas mantém a barra desenhada
        // sobre a janela: reserva a altura da barra pelo recurso do sistema —
        // espaço a mais é cosmético, botão escondido é inutilizável.
        val resId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        val fallback = if (resId > 0) resources.getDimensionPixelSize(resId) else 0
        Log.w(TAG, "insets: barra sem inset reportado, usando recurso=${fallback}px")
        return fallback
    }

    // MARK: Ditado

    private fun toggleDictation() {
        when (state) {
            State.Listening, State.Connecting -> stopDictation()
            State.Finishing -> Unit
            State.Idle, State.Error -> startDictation()
        }
    }

    private fun startDictation() {
        session = KeyboardSession.load(this)
        if (!session.hasApiKey) {
            statusOverride = "Sem chave Soniox neste perfil. Defina em Início, no app."
            state = State.Error
            render()
            return
        }
        if (dictation != null) return

        startForegroundForMic()
        nothingToTranslate = false
        preview = ""
        statusOverride = null
        state = State.Connecting
        render()

        dictation = DictationSession(this, session) { update ->
            if (update.connected) {
                state = State.Listening
                render()
            }
            update.error?.let { message ->
                statusOverride = message
                state = State.Error
                render()
            }
            if (update.nothingToTranslate) nothingToTranslate = true
            update.preview?.let {
                preview = it
                render()
            }
            update.finalText?.let { text ->
                // Finais são deltas: cada evento traz só o que acabou de virar
                // final, então concatenar no campo é o certo.
                currentInputConnection?.commitText(text, 1)
                preview = ""
                render()
            }
            if (update.finished) {
                dictation?.release()
                dictation = null
                if (state != State.Error) state = State.Idle
                preview = ""
                nothingToTranslate = false
                render()
                stopForegroundQuietly()
            }
        }.also { it.start() }
    }

    private fun stopDictation() {
        val running = dictation ?: return
        if (state == State.Listening || state == State.Connecting) {
            state = State.Finishing
            render()
        }
        running.stop()
    }

    // MARK: Ações de tecla

    private fun deleteBackward() {
        val connection = currentInputConnection
        Log.d(TAG, "deleteBackward: connection=${connection != null}")
        if (connection == null) return
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL))
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL))
    }

    private fun commitSpace() {
        val connection = currentInputConnection
        Log.d(TAG, "commitSpace: connection=${connection != null}")
        // `commitText` é o caminho normal; alguns campos (busca do sistema)
        // ignoram texto sem composição — nesse caso a tecla parece morta.
        connection?.commitText(" ", 1)
    }

    private fun commitEnter() {
        val connection = currentInputConnection ?: return
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_ENTER))
        connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_ENTER))
    }

    private fun switchToLetterKeyboard() {
        val manager = getSystemService(InputMethodManager::class.java)
        val switched = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            switchToNextInputMethod(false)
        } else {
            false
        }
        if (!switched) manager?.showInputMethodPicker()
    }

    // MARK: Serviço em primeiro plano (microfone)

    /**
     * Android 11+ só entrega o microfone para serviço em primeiro plano. O
     * teclado visível já conta como "em uso", mas declarar o serviço como
     * `microphone` é o caminho documentado; se o sistema recusar, seguimos sem
     * — e a captura, se falhar, avisa na linha de status.
     */
    private fun startForegroundForMic() {
        if (foreground) return
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager?.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Ditado no teclado",
                        NotificationManager.IMPORTANCE_LOW,
                    ),
                )
            }
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION") Notification.Builder(this)
            }
            val notification = builder
                .setContentTitle("Soniox")
                .setContentText("Ditado em andamento")
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
                .setOngoing(true)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            foreground = true
        } catch (e: Exception) {
            // Sem primeiro plano: tenta mesmo assim; um SecurityException do
            // AudioRecord aparece na linha de status.
            foreground = false
        }
    }

    private fun stopForegroundQuietly() {
        if (!foreground) return
        foreground = false
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            // Serviço já fora do primeiro plano.
        }
    }

    // MARK: Render

    private fun render() {
        val accent = when (state) {
            State.Listening -> RECORDING
            State.Connecting, State.Finishing -> WORKING
            State.Error -> ERROR
            State.Idle -> ACCENT
        }

        micView.text = when (state) {
            State.Listening -> "parar"
            State.Connecting -> "…"
            State.Finishing -> "…"
            State.Error -> "tentar de novo"
            State.Idle -> "🎤  gravar"
        }
        micView.background = rounded(accent, dp(32))

        statusView.text = when {
            statusOverride != null -> statusOverride
            !session.hasApiKey -> "Sem chave Soniox neste perfil (defina em Início, no app)."
            state == State.Listening || state == State.Finishing ->
                if (session.translates) "Traduzindo para ${session.translationTarget}" else "Ouvindo…"
            state == State.Connecting -> "Conectando…"
            else -> if (session.translates) {
                "Toque para falar — o texto sai em ${session.translationTarget}"
            } else {
                "Toque no microfone e fale"
            }
        }
        statusView.setTextColor(if (state == State.Error) ERROR else secondaryColor())

        previewView.text = when {
            preview.isNotEmpty() -> preview
            nothingToTranslate -> "Nada para traduzir: a fala já está no idioma alvo."
            state == State.Listening -> "…"
            else -> ""
        }
        previewView.setTextColor(
            if (preview.isNotEmpty()) primaryColor() else secondaryColor(),
        )
    }

    private fun rounded(color: Int, radius: Int) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = radius.toFloat()
    }

    private fun primaryColor() = if (isNight) Color.parseColor("#F2F2F7") else Color.parseColor("#1C1C1E")

    private fun secondaryColor() = if (isNight) Color.parseColor("#9A9AA0") else Color.parseColor("#6C6C70")

    private fun dp(value: Int) = (value * density).toInt()

    companion object {
        private const val TAG = "SonioxKeyboard"
        private const val CHANNEL_ID = "soniox_keyboard_dictation"
        private const val NOTIFICATION_ID = 4711
        private const val ACCENT = 0xFF0A84FF.toInt()
        private const val RECORDING = 0xFFFF3B30.toInt()
        private const val WORKING = 0xFFFF9F0A.toInt()
        private const val ERROR = 0xFFD32F2F.toInt()
        private const val NIGHT_BACKGROUND = 0xFF1C1B1A.toInt()
        private const val LIGHT_BACKGROUND = 0xFFF2F2F7.toInt()
        private const val NIGHT_KEY = 0xFF2F2E2D.toInt()
        private const val LIGHT_KEY = 0xFFFFFFFF.toInt()
    }
}
