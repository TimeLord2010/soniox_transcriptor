import 'package:flutter/cupertino.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/repositories/hotkey_listener.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:soniox_transcriptor/repositories/soniox_websocket_impl.dart';
import 'package:vit_soniox/vit_soniox.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final hotkeyListener = HotkeyListener(onKeyDown: () {}, onKeyUp: () {});
  final recorder = RecorderRepository();
  SonioxWebsocket? soniox;

  @override
  void initState() {
    hotkeyListener.start();
    super.initState();
  }

  @override
  void dispose() {
    HotkeyListener.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Vit transcriptor'),
        backgroundColor: CupertinoColors.systemBackground,
      ),
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16.0), child: _content()),
      ),
    );
  }

  Column _content() {
    return Column(
      spacing: 20,
      children: [
        ApiKeySetter(
          onApiKeyChanged: (value) {
            _updateSonioxInstance(apiKey: value ?? '');
          },
        ),
        DevicePicker(recorder: recorder),
      ],
    );
  }

  // MARK: Events

  void _updateSonioxInstance({String apiKey = ''}) {
    // Reset
    hotkeyListener.onKeyDown = () {};
    hotkeyListener.onKeyUp = () {};
    soniox?.disconnect();
    recorder.stop();

    if (apiKey.isEmpty) {
      return;
    }

    // Updating state
    debugPrint('Creating soniox websocket with api key');
    var current = soniox = SonioxWebsocket(
      SonioxSessionConfig(
        apiKey: apiKey,
        audio: AudioConfig.pcms16le(),
        languageHints: ['pt', 'en'],
        languageStrict: true,
      ),
      websocket: SonioxWebsocketImpl(),
    );

    current.connectionStream.listen((connect) async {
      debugPrint('Connected! $connect');
      if (connect) {
        await recorder.start();
        debugPrint('Recording...');
        recorder.recordStream.listen((data) {
          current.addAudio(data);
        });
      }
    });

    final buffer = StringBuffer();
    String nonFinal = '';

    hotkeyListener.onKeyDown = () {
      current.transcription.listen((transcription) {
        buffer.write(transcription.finalText);
        nonFinal = transcription.nonFinalText;
      });

      current.connect();
      debugPrint('Connect command');
    };
    hotkeyListener.onKeyUp = () {
      var textToPast = buffer.toString() + nonFinal;
      if (textToPast.isNotEmpty) {
        HotkeyListener.pasteText(textToPast);
      }
      current.disconnect();
      recorder.stop();
      _updateSonioxInstance(apiKey: apiKey);
    };
  }
}
