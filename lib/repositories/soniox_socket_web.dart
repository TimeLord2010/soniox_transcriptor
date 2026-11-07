import 'package:web_socket_channel/web_socket_channel.dart';

/// Navegador: `WebSocket` não deixa mandar header no handshake. O Soniox lê a
/// chave na lista de subprotocolos — `soniox-api-key` seguido da chave. Mandar
/// header E subprotocolo (ou `soniox-api-key` sem chave) é erro 400.
WebSocketChannel openSonioxSocket(Uri url, String apiKey) =>
    WebSocketChannel.connect(url, protocols: ['soniox-api-key', apiKey]);
