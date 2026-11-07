import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Desktop/mobile/servidor: a chave vai no header do upgrade, que é o caminho
/// padrão do Soniox fora do navegador.
WebSocketChannel openSonioxSocket(Uri url, String apiKey) =>
    IOWebSocketChannel.connect(
      url,
      headers: {'Authorization': 'Bearer $apiKey'},
    );
