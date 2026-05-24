import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

class RecorderRepository {
  final _record = AudioRecorder();

  StreamController<Uint8List> _recordStreamController =
      StreamController.broadcast();
  // Subscription to forward native audio chunks to the broadcast controller.
  StreamSubscription<Uint8List>? _nativeSubscription;

  Stream<Uint8List> get recordStream => _recordStreamController.stream;

  List<InputDevice> devices = [];
  InputDevice? selectedDevice;

  Future<void> listInputDevices() async {
    devices = await _record.listInputDevices();
    debugPrint('Found devices: ${devices.map((x) => x.label).join(',')}');
  }

  Future<void> start() async {
    var isAllowedToRecord = await _record.hasPermission();
    if (!isAllowedToRecord) {
      return;
    }
    final stream = await _record.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
        device: selectedDevice,
      ),
    );
    // Forward the native audio stream to the broadcast controller using a listener.
    // Cancel any previous subscription to avoid duplicate listeners.
    _nativeSubscription?.cancel();
    _nativeSubscription = stream.listen((data) {
      _recordStreamController.add(data);
    });
  }

  Future<void> stop() async {
    // Cancel the native audio subscription before stopping the recorder.
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
    await _record.stop();
  }

  /// Reset the internal stream controller for a fresh recording session.
  /// This should be called when a new transcription session is started
  /// after the previous one has been stopped.
  Future<void> reset() async {
    // Cancel any active native audio subscription.
    _nativeSubscription?.cancel();
    _nativeSubscription = null;

    // Close the existing controller if it hasn't been closed yet.
    _recordStreamController.close();

    // Create a new broadcast controller.
    _recordStreamController = StreamController.broadcast();
  }
}
