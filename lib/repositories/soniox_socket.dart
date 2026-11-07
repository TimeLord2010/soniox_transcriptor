import 'package:web_socket_channel/web_socket_channel.dart';

import 'soniox_socket_stub.dart'
    if (dart.library.io) 'soniox_socket_io.dart'
    if (dart.library.js_interop) 'soniox_socket_web.dart'
    as impl;

/// Abre o WebSocket da Soniox com a chave NA CONEXÃO, como a API real-time
/// passou a exigir (chave no primeiro frame deixa de valer em 15/01/2027).
///
/// O transporte difere por plataforma e não dá para escolher em runtime:
/// `dart:io` aceita o header `Authorization`, o navegador NÃO aceita header
/// nenhum em WebSocket e recebe a chave na lista de subprotocolos. Importar
/// `package:web_socket_channel/io.dart` num build web quebra o dart2js, daí o
/// import condicional.
WebSocketChannel openSonioxSocket(Uri url, String apiKey) =>
    impl.openSonioxSocket(url, apiKey);
