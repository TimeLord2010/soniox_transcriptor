package com.vit.soniox

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/**
 * Avisa o Flutter quando uma entrada de áudio é plugada ou removida
 * (`AudioDeviceCallback`), no lugar de ficar consultando a lista. O evento não
 * traz a lista: só manda reler.
 */
class InputDevicesChannel(context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var callback: AudioDeviceCallback? = null

    init {
        EventChannel(messenger, CHANNEL).setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val cb = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                if (addedDevices.any { it.isSource }) events.success(null)
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                if (removedDevices.any { it.isSource }) events.success(null)
            }
        }
        callback = cb
        audioManager.registerAudioDeviceCallback(cb, Handler(Looper.getMainLooper()))
    }

    override fun onCancel(arguments: Any?) {
        callback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        callback = null
    }

    companion object {
        private const val CHANNEL = "com.vit.soniox/input_devices_changed"
    }
}
