package com.vit.soniox

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import android.view.inputmethod.InputMethodManager
import com.vit.soniox.keyboard.SonioxKeyboardService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /**
     * Id do teclado como o sistema escreve em `Settings.Secure`: ele usa a
     * forma curta (`pacote/.classe.Relativa`) por padrão, mas a forma completa
     * aparece depois de algumas atualizações de app — as duas contam.
     */
    private val imeIds: List<String>
        get() = listOf(
            "$packageName/${SonioxKeyboardService::class.java.name}",
            "$packageName/.keyboard.SonioxKeyboardService",
        )

    /** Ids dos teclados habilitados, pela API pública (`InputMethodManager`). */
    private val enabledImeIds: List<String>
        get() = try {
            val manager = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            manager?.enabledInputMethodList.orEmpty().map { "${it.packageName}/${it.serviceName}" }
        } catch (e: Exception) {
            emptyList()
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // O Flutter não fala com o gerenciador de teclados: só a Activity pode
        // abrir a lista de teclados e mostrar o seletor do sistema.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> {
                        val rawEnabled = secureSetting(Settings.Secure.ENABLED_INPUT_METHODS)
                        val rawDefault = secureSetting(Settings.Secure.DEFAULT_INPUT_METHOD)
                        Log.d(
                            TAG,
                            "enabled=$rawEnabled default=$rawDefault " +
                                "enabled(api)=$enabledImeIds",
                        )
                        result.success(
                            mapOf(
                                "enabled" to isImeEnabled(rawEnabled),
                                "selected" to isImeSelected(rawDefault),
                            ),
                        )
                    }

                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
                        result.success(null)
                    }

                    "showPicker" -> {
                        val manager = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                        manager?.showInputMethodPicker()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Lê uma chave de `Settings.Secure`. Nestas versões do Android o sistema
     * LANÇA `SecurityException` para app comum (a chave deixou de ser pública),
     * então a leitura é opcional e nunca derruba a chamada do Flutter.
     */
    private fun secureSetting(key: String): String? {
        return try {
            Settings.Secure.getString(contentResolver, key)
        } catch (e: Exception) {
            Log.d(TAG, "Settings.Secure.$key ilegível: ${e.javaClass.simpleName}")
            null
        }
    }

    /**
     * Habilitado: `Settings.Secure` quando legível e, de reserva, a lista
     * pública de teclados habilitados (o sistema nega a chave Secure para app
     * comum em versões recentes).
     */
    private fun isImeEnabled(rawEnabled: String?): Boolean {
        if (rawEnabled != null) {
            return rawEnabled.split(':').any { it in imeIds }
        }
        return enabledImeIds.any { it in imeIds }
    }

    private fun isImeSelected(rawDefault: String?): Boolean {
        return rawDefault != null && rawDefault in imeIds
    }

    private companion object {
        const val CHANNEL = "soniox/keyboard"
        const val TAG = "SonioxKeyboardStatus"
    }
}
