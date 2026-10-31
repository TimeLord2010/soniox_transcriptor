import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:record/record.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';

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

  /// Quanto esperar o plugin ABRIR a captura. No navegador `getUserMedia` pode
  /// nunca resolver (permissão de microfone travada) e aí o app ficava parado
  /// para sempre, sem toast: o `await` de `startStream` nunca voltava.
  static const defaultStartTimeout = Duration(seconds: 8);

  /// Limite em vigor; os testes encurtam para não esperar 8 s.
  @visibleForTesting
  Duration startTimeout = defaultStartTimeout;

  // Criado sob demanda: o construtor do plugin já fala com o canal nativo, e
  // um teste que troca o gravador não deve tocar no plugin.
  late final AudioRecorder _record = AudioRecorder();

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

  /// Mensagem única de microfone negado. O texto por sistema mora no
  /// [PlatformSupport] — aqui era uma cópia da decisão de plataforma, e ela
  /// quebrava no web.
  static String get permissionDeniedMessage =>
      PlatformSupport.micPermissionDeniedMessage;

  Future<void> listInputDevices() async {
    try {
      devices = await _record.listInputDevices();
    } catch (error) {
      // Nem toda plataforma expõe o enumerador; sem lista, o picker fica
      // desabilitado e a captura usa o microfone padrão.
      debugPrint('[recorder] listInputDevices falhou: $error');
      devices = [];
    }
    debugPrint('Found devices: ${devices.map((x) => x.label).join(',')}');
  }

  /// Pede a permissão de microfone antes da sessão. No Android é aqui que o
  /// diálogo do sistema aparece; sem isso a primeira gravação morreria em erro
  /// depois de abrir a conexão com a Soniox.
  Future<bool> requestMicPermission() async {
    final allowed = await hasPluginPermission();
    debugPrint('[recorder] permissão de microfone: $allowed');
    return allowed;
  }

  Future<void> start() async {
    final generation = ++_generation;
    // Também com limite: no navegador a consulta de permissão pode pendurar.
    final isAllowedToRecord = await hasPluginPermission().timeout(
      startTimeout,
      onTimeout: () => false,
    );
    if (!isAllowedToRecord) {
      _emitError(permissionDeniedMessage);
      return;
    }

    String? lastFailure;
    for (var attempt = 1; attempt <= maxStartAttempts; attempt++) {
      if (generation != _generation) {
        // The session was stopped while a capture was being (re)started.
        return;
      }
      try {
        await _startCapture().timeout(startTimeout);
        if (await _waitForFirstChunk()) {
          if (attempt > 1) {
            debugPrint('[recorder] captura iniciada na tentativa $attempt');
          }
          return;
        }
        lastFailure =
            'nenhum áudio chegou em ${firstChunkTimeout.inMilliseconds} ms';
      } on TimeoutException {
        // Não adianta tentar de novo: se o plugin não abriu a captura no
        // limite, é permissão travada, não falha de dispositivo.
        lastFailure =
            'o microfone não abriu em ${startTimeout.inSeconds}s '
            '(${PlatformSupport.name})';
        debugPrint('[recorder] tentativa $attempt estourou: $lastFailure');
        await _stopCapture();
        break;
      } catch (error) {
        lastFailure = '$error';
      }
      debugPrint('[recorder] tentativa $attempt falhou: $lastFailure');
      await _stopCapture();
    }

    final hint = PlatformSupport.isWeb
        ? 'Libere o microfone para este site no navegador '
              '(ícone da barra de endereços) e tente de novo.'
        : 'Tente trocar o dispositivo ou reconectar o microfone.';
    _emitError(
      'Não foi possível capturar áudio do microfone '
      '"${selectedDevice?.label ?? 'padrão'}". $hint ($lastFailure)',
    );
  }

  Future<void> _startCapture() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;

    final firstChunk = _firstChunk = Completer<void>();
    final stream = await openAudioStream();
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

  /// Pergunta ao plugin se o microfone está liberado (`getUserMedia` no web).
  ///
  /// Costura de teste, como [openAudioStream]: o plugin real não deixa simular
  /// a permissão travada do navegador.
  @visibleForTesting
  Future<bool> hasPluginPermission() => _record.hasPermission();

  /// Abre o stream de áudio do plugin.
  ///
  /// Costura de teste: o `AudioRecorder` real é `late final` e não deixa
  /// simular o caso do navegador, em que `getUserMedia` nunca resolve.
  @visibleForTesting
  Future<Stream<Uint8List>> openAudioStream() {
    return _record.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
        device: selectedDevice,
      ),
    );
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
