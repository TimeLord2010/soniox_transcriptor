import 'dart:typed_data';

import 'package:vit_soniox/vit_soniox.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SonioxWebsocketImpl with WebsocketContract {
  WebSocketChannel? _channel;

  @override
  Future<void> connect(String url) async {
    _channel = WebSocketChannel.connect(Uri.parse(url));
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
