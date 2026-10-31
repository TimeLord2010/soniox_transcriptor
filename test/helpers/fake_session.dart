import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:vit_soniox/vit_soniox.dart';

/// Transporte falso: guarda o que o app mandou e deixa o teste empurrar as
/// mensagens do servidor. Serve para exercitar a sessão inteira (config
/// enviada, tokens chegando, texto na tela) sem rede e sem microfone.
class FakeServer with WebsocketContract {
  final _incoming = StreamController<String>();
  final sentText = <String>[];
  final sentAudio = <Uint8List>[];
  bool connected = false;

  /// Config que o app mandou no `start` da sessão.
  Map<String, dynamic>? get sentConfig {
    if (sentText.isEmpty) return null;
    return jsonDecode(sentText.first) as Map<String, dynamic>;
  }

  @override
  Future<void> connect(String url) async => connected = true;

  @override
  Stream<String> get stream => _incoming.stream;

  @override
  void send(String data) => sentText.add(data);

  @override
  void sendBinary(Uint8List data) => sentAudio.add(data);

  @override
  void close() => connected = false;

  /// Entrega um evento do Soniox para a sessão.
  void push(Map<String, dynamic> event) => _incoming.add(jsonEncode(event));

  Future<void> dispose() => _incoming.close();
}

/// Gravador falso: sem plugin de áudio e sem microfone. `start()` emite um
/// chunk, que é o sinal que a sessão espera para considerar a captura viva.
class FakeRecorder extends RecorderRepository {
  final _audio = StreamController<Uint8List>.broadcast();
  final _errors = StreamController<String>.broadcast();

  int starts = 0;
  int stops = 0;

  @override
  Stream<Uint8List> get recordStream => _audio.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<bool> requestMicPermission() async => true;

  @override
  Future<void> start() async {
    starts++;
    _audio.add(Uint8List.fromList(List<int>.filled(3200, 0)));
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> reset() async {}

  @override
  void dispose() {
    _audio.close();
    _errors.close();
  }
}
