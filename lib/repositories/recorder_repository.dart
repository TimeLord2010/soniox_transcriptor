import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

/// Microphone capture for the transcription session.
///
/// `AVAudioEngine` (used by `record_macos`) may silently hand the input back to
/// the system default device while starting the capture — with a Bluetooth
/// headset connected, macOS routes the default through a private aggregate and
/// the tap bound to the selected microphone never fires. No audio, no error.
/// `start()` therefore verifies that audio actually flows and retries, and any
/// failure is reported on [errors] instead of dying silently.
class RecorderRepository {
  /// How long to wait for the first audio chunk before rebuilding the capture.
  static const firstChunkTimeout = Duration(milliseconds: 1000);

  /// Full capture starts (the native plugin already retries internally).
  static const maxStartAttempts = 2;

  final _record = AudioRecorder();

  StreamController<Uint8List> _recordStreamController =
      StreamController.broadcast();
  // Subscription to forward native audio chunks to the broadcast controller.
  StreamSubscription<Uint8List>? _nativeSubscription;

  final _errorController = StreamController<String>.broadcast();

  // Completed when the first audio chunk of the current capture arrives.
  Completer<void>? _firstChunk;

  // Invalidates a capture start that is still retrying when the session ends.
  int _generation = 0;

  Stream<Uint8List> get recordStream => _recordStreamController.stream;

  /// User-facing failures (nothing is thrown to the caller).
  Stream<String> get errors => _errorController.stream;

  List<InputDevice> devices = [];
  InputDevice? selectedDevice;

  Future<void> listInputDevices() async {
    devices = await _record.listInputDevices();
    debugPrint('Found devices: ${devices.map((x) => x.label).join(',')}');
  }

  Future<void> start() async {
    final generation = ++_generation;
    final isAllowedToRecord = await _record.hasPermission();
    if (!isAllowedToRecord) {
      _emitError(
        'Permissão de microfone negada. Autorize o soniox_transcriptor em '
        'Ajustes do Sistema > Privacidade e Segurança > Microfone.',
      );
      return;
    }

    String? lastFailure;
    for (var attempt = 1; attempt <= maxStartAttempts; attempt++) {
      if (generation != _generation) {
        // The session was stopped while a capture was being (re)started.
        return;
      }
      try {
        await _startCapture();
        if (await _waitForFirstChunk()) {
          if (attempt > 1) {
            debugPrint('[recorder] captura iniciada na tentativa $attempt');
          }
          return;
        }
        lastFailure =
            'nenhum áudio chegou em ${firstChunkTimeout.inMilliseconds} ms';
      } catch (error) {
        lastFailure = '$error';
      }
      debugPrint('[recorder] tentativa $attempt falhou: $lastFailure');
      await _stopCapture();
    }

    _emitError(
      'Não foi possível capturar áudio do microfone '
      '"${selectedDevice?.label ?? 'padrão'}". '
      'Tente trocar o dispositivo ou reconectar o microfone. ($lastFailure)',
    );
  }

  Future<void> _startCapture() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;

    final firstChunk = _firstChunk = Completer<void>();
    final stream = await _record.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
        device: selectedDevice,
      ),
    );
    // Forward the native audio stream to the broadcast controller using a
    // listener. Cancel any previous subscription to avoid duplicate listeners.
    _nativeSubscription = stream.listen((data) {
      if (!firstChunk.isCompleted) {
        firstChunk.complete();
      }
      if (!_recordStreamController.isClosed) {
        _recordStreamController.add(data);
      }
    });
  }

  /// Waits for the first chunk of the capture in flight.
  Future<bool> _waitForFirstChunk() async {
    final firstChunk = _firstChunk;
    if (firstChunk == null) {
      return false;
    }
    if (firstChunk.isCompleted) {
      return true;
    }
    try {
      await firstChunk.future.timeout(firstChunkTimeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _stopCapture() async {
    _firstChunk = null;
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    try {
      await _record.stop();
    } catch (error) {
      debugPrint('[recorder] stop() falhou: $error');
    }
  }

  Future<void> stop() async {
    _generation++;
    await _stopCapture();
  }

  /// Reset the internal stream controller for a fresh recording session.
  /// This should be called when a new transcription session is started
  /// after the previous one has been stopped.
  Future<void> reset() async {
    _generation++;
    await _stopCapture();

    // Close the existing controller if it hasn't been closed yet.
    await _recordStreamController.close();

    // Create a new broadcast controller.
    _recordStreamController = StreamController.broadcast();
  }

  void _emitError(String message) {
    debugPrint('[recorder] $message');
    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }

  void dispose() {
    _stopCapture();
    _errorController.close();
  }
}
