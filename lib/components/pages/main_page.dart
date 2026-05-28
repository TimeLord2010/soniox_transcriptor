import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/components/styles/glass_config.dart';
import 'package:soniox_transcriptor/components/terms_picker.dart';
import 'package:soniox_transcriptor/components/transcriptions_history.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';
import 'package:soniox_transcriptor/providers/history_provider.dart';
import 'package:soniox_transcriptor/repositories/hotkey_listener.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:soniox_transcriptor/repositories/soniox_websocket_impl.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';
import 'package:vit_soniox/vit_soniox.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  final hotkeyListener = HotkeyListener(onKeyDown: () {}, onKeyUp: () {});
  final recorder = RecorderRepository();
  SonioxWebsocket? soniox;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<List<int>>? _recordStreamSubscription;
  StreamSubscription? _transcriptionSubscription;
  bool _isProcessing = false;

  int currentPage = 0;

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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 234, 239, 241),
      appBar: AppBar(title: Text('Vit transcriptor')),
      body: _content(),
      extendBody: true,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: GlassBottomBar(
        quality: GlassQuality.premium,
        glassSettings: glassSettings,
        tabs: [
          GlassBottomBarTab(icon: Icon(Icons.home, color: Colors.black)),
          GlassBottomBarTab(icon: Icon(Icons.history, color: Colors.black)),
        ],
        selectedIndex: currentPage,
        onTabSelected: (value) {
          currentPage = value;
          setState(() {});
        },
      ),
    );
  }

  Widget _content() {
    return switch (currentPage) {
      0 => _homePage(),
      1 => TranscriptionsHistory(),
      _ => Placeholder(),
    };
  }

  Widget _homePage() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 20,
        children: [
          ApiKeySetter(
            onApiKeyChanged: (value) {
              _updateSonioxInstance(apiKey: value ?? '');
            },
          ),
          DevicePicker(recorder: recorder),
          TermsPicker(),
          if (kReleaseMode) _sandbox(),
        ],
      ),
    );
  }

  Column _sandbox() {
    return Column(
      crossAxisAlignment: .start,
      spacing: 5,
      children: [
        Text('Sandbox'),
        Row(
          spacing: 10,
          children: [
            Expanded(child: GlassTextArea(maxLines: 5)),
            ElevatedButton(
              onPressed: () {},
              child: Icon(Icons.record_voice_over),
            ),
          ],
        ),
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
    _connectionSubscription?.cancel();
    _recordStreamSubscription?.cancel();
    _transcriptionSubscription?.cancel();

    if (apiKey.isEmpty) {
      return;
    }

    var terms = ref.read(termsProvider);

    // Updating state
    debugPrint('Creating soniox websocket with api key');
    var sonioxSessionConfig = SonioxSessionConfig(
      apiKey: apiKey,
      audio: AudioConfig.pcms16le(),
      languageHints: ['pt', 'en'],
      languageStrict: true,
      context: SessionContext(text: null, terms: terms),
    );
    var current = soniox = SonioxWebsocket(
      sonioxSessionConfig,
      websocket: SonioxWebsocketImpl(),
    );

    _connectionSubscription = current.connectionStream.listen((connect) async {
      debugPrint('Connected! $connect');
      if (connect) {
        await recorder.start();
        debugPrint('Recording...');
        _recordStreamSubscription = recorder.recordStream.listen((data) {
          current.addAudio(data);
        });
      } else {
        _recordStreamSubscription?.cancel();
      }
    });

    final buffer = StringBuffer();
    String nonFinal = '';

    hotkeyListener.onKeyDown = () {
      if (_isProcessing) return;
      _isProcessing = true;

      HotkeyListener.showOverlay();

      _transcriptionSubscription?.cancel();
      _transcriptionSubscription = current.transcription.listen((
        transcription,
      ) {
        buffer.write(transcription.finalText);
        nonFinal = transcription.nonFinalText;
        HotkeyListener.updateTranscription(buffer.toString(), nonFinal);
      });

      current.connect();
      debugPrint('Connect command');
    };
    hotkeyListener.onKeyUp = () {
      if (!_isProcessing) return;

      HotkeyListener.hideOverlay();

      var textToPast = buffer.toString() + nonFinal;
      if (textToPast.isNotEmpty) {
        GetIt.I.get<TranscriptionRepository>().insert(
          TranscriptionRecord(
            finalText: buffer.toString(),
            nonFinalText: nonFinal,
            createdAt: DateTime.now(),
          ),
        );
        ref.invalidate(historyProvider);
        HotkeyListener.pasteText(textToPast);
      }
      current.disconnect();
      recorder.stop();
      _isProcessing = false;
      _updateSonioxInstance(apiKey: apiKey);
    };
  }
}
