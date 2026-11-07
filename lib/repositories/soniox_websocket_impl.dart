import 'dart:typed_data';

import 'package:get_it/get_it.dart';
import 'package:vit_soniox/vit_soniox.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'soniox_socket.dart';

/// Fábrica do transporte da sessão. Fica no GetIt para o teste poder abrir uma
/// sessão de verdade (config enviada, tokens chegando, texto na tela) contra um
/// servidor falso — sem isso o caminho da sessão só roda no app real.
typedef WebsocketFactory = WebsocketContract Function();

/// Transporte real; sem fábrica registrada (app normal) é o usado.
WebsocketContract createWebsocket() {
  final factory = GetIt.I.isRegistered<WebsocketFactory>()
      ? GetIt.I.get<WebsocketFactory>()
      : null;
  return factory?.call() ?? SonioxWebsocketImpl();
}

class SonioxWebsocketImpl with WebsocketContract {
  WebSocketChannel? _channel;

  @override
  Future<void> connect(String url, {String? apiKey}) async {
    // A chave é da CONEXÃO: header no IO, subprotocolo no navegador. Sessão sem
    // chave nem chega aqui (a tela não abre sem ela), mas falhar aqui é mais
    // claro do que um 401 vindo do servidor depois.
    final key = apiKey?.trim() ?? '';
    if (key.isEmpty) {
      throw StateError('Sessão Soniox sem chave de API');
    }
    _channel = openSonioxSocket(Uri.parse(url), key);
    await _channel!.ready.timeout(Duration(seconds: 5));
  }

  @override
  Stream<String> get stream => _channel!.stream.cast<String>();

  @override
  void send(String data) => _channel?.sink.add(data);

  @override
  void sendBinary(Uint8List data) => _channel?.sink.add(data);

  @override
  void close() => _channel?.sink.close();
}
