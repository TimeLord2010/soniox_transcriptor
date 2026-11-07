import 'package:web_socket_channel/web_socket_channel.dart';

/// Fora de `dart:io` e do navegador não existe WebSocket para abrir. Não é
/// alcançável nos alvos do app (macOS, Android, web) — falha alto e claro.
WebSocketChannel openSonioxSocket(Uri url, String apiKey) =>
    throw UnsupportedError('WebSocket Soniox não suportado nesta plataforma');
