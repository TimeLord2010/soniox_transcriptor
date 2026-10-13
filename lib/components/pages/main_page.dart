import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/components/context_text_setter.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/components/language_picker.dart';
import 'package:soniox_transcriptor/components/profile_selector.dart';
import 'package:soniox_transcriptor/components/styles/glass_config.dart';
import 'package:soniox_transcriptor/components/terms_picker.dart';
import 'package:soniox_transcriptor/components/transcriptions_history.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/providers/api_key_provider.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';
import 'package:soniox_transcriptor/providers/history_provider.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
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
  late final hotkeyListener = HotkeyListener(
    onKeyDown: () {},
    onKeyUp: () {},
    onInsertText: _insertIntoSandbox,
  );
  final recorder = RecorderRepository();
  final _sandboxController = TextEditingController();
  final _sandboxFocusNode = FocusNode();
  SonioxWebsocket? soniox;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<List<int>>? _recordStreamSubscription;
  StreamSubscription? _transcriptionSubscription;
  StreamSubscription<String>? _errorSubscription;
  bool _isProcessing = false;

  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    hotkeyListener.start().catchError((Object e) {
      debugPrint('[MainPage] hotkeyListener.start() error: $e');
    });
    _updateSonioxInstance();
  }

  @override
  void dispose() {
    // The native hotkey monitor is a single, app-global resource. MainPage can
    // mount more than once (the LiquidGlass/theme wrapper rebuilds the subtree),
    // and calling the static stop() here would tear down the monitor that a
    // newer, still-alive MainPage just registered. Let it live for the app's
    // lifetime; the OS reclaims it on exit.
    _sandboxController.dispose();
    _sandboxFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The session depends on the active profile (key, terms, languages and
    // context), so rebuild it when either the key or the profile changes.
    // Both can fire in the same frame on a switch; coalesce into one rebuild.
    ref.listen(apiKeyProvider, (_, _) => _scheduleSessionRebuild());
    ref.listen(activeProfileIdProvider, (_, _) => _scheduleSessionRebuild());
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 234, 239, 241),
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
    // Keying the settings by profile remounts them on switch, so each one
    // reloads its values.
    final profileId = ref.watch(activeProfileIdProvider);
    final hasApiKey = ref.watch(apiKeyProvider).isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 20,
        children: [
          ProfileSelector(),
          if (!hasApiKey) _missingApiKeyNotice(),
          ApiKeySetter(key: ValueKey('api-key-$profileId')),
          DevicePicker(key: ValueKey('device-$profileId'), recorder: recorder),
          TermsPicker(),
          LanguagePicker(),
          ContextTextSetter(key: ValueKey('context-$profileId')),
          _sandbox(),
        ],
      ),
    );
  }

  Widget _missingApiKeyNotice() {
    return GlassCard(
      useOwnLayer: true,
      padding: const EdgeInsets.all(12),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
          Expanded(
            child: Text(
              'Este perfil não tem chave Soniox. O atalho não vai gravar '
              'até que uma chave seja definida.',
              style: TextStyle(color: Colors.black),
            ),
          ),
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
        GlassTextArea(
          controller: _sandboxController,
          focusNode: _sandboxFocusNode,
          maxLines: 5,
          useOwnLayer: true,
          textStyle: TextStyle(color: Colors.black),
        ),
      ],
    );
  }

  /// Inserts [text] into the sandbox field at the current cursor position,
  /// replacing any selection. Invoked by the native side when the transcription
  /// finishes while this app is in the foreground.
  void _insertIntoSandbox(String text) {
    final value = _sandboxController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final newText = value.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    final newOffset = selection.start + text.length;
    _sandboxController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _sandboxFocusNode.requestFocus();
  }

  // MARK: Events

  bool _rebuildScheduled = false;

  void _scheduleSessionRebuild() {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    scheduleMicrotask(() {
      _rebuildScheduled = false;
      if (mounted) _updateSonioxInstance();
    });
  }

  void _updateSonioxInstance() {
    // A recording is in flight: key-up rebuilds the session from the current
    // providers right after, so don't tear it down now.
    if (_isProcessing) return;
    final apiKey = ref.read(apiKeyProvider);

    // Reset
    hotkeyListener.onKeyDown = () {};
    hotkeyListener.onKeyUp = () {};
    soniox?.disconnect();
    recorder.stop();
    _connectionSubscription?.cancel();
    _recordStreamSubscription?.cancel();
    _transcriptionSubscription?.cancel();
    _errorSubscription?.cancel();

    if (apiKey.isEmpty) {
      return;
    }

    var terms = ref.read(termsProvider);
    var languageValues = ref.read(languagesProvider);
    var languages = languageValues.map((x) => x.name).toList();
    var cText = ref.read(contextProvider);

    // Updating state
    debugPrint('Creating soniox websocket with api key');
    var sonioxSessionConfig = SonioxSessionConfig(
      apiKey: apiKey,
      model: 'stt-rt-v5',
      audio: AudioConfig.pcms16le(),
      languageHints: languages,
      languageStrict: languages.isNotEmpty,
      context: SessionContext(text: cText, terms: terms),
    );
    var current = soniox = SonioxWebsocket(
      sonioxSessionConfig,
      websocket: SonioxWebsocketImpl(),
    );

    _connectionSubscription = current.connectionStream.listen((connect) async {
      debugPrint('Connected! $connect');
      if (connect) {
        HotkeyListener.setListening();
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
    String? sessionError;

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

      // Read errors from the raw messages: vit_soniox's `errors` stream never
      // fires, since it expects `error_code` as a String while Soniox sends an
      // int, so errors are dropped as empty transcriptions.
      _errorSubscription?.cancel();
      _errorSubscription = current.rawMessages.listen((message) {
        final error = _parseSonioxError(message);
        if (error == null || sessionError != null) return;
        sessionError = error;
        debugPrint('Soniox error: $error');
        HotkeyListener.showError(error);
        _recordStreamSubscription?.cancel();
        recorder.stop();
      });

      current.connect();
      debugPrint('Connect command');
    };
    hotkeyListener.onKeyUp = () {
      if (!_isProcessing) return;

      // Keep an error on screen long enough to read after the key is released.
      HotkeyListener.hideOverlay(
        delay: sessionError == null ? null : const Duration(seconds: 4),
      );

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
      _updateSonioxInstance();
    };
  }

  /// Returns a user-facing message if [message] is a Soniox error response.
  String? _parseSonioxError(String message) {
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (decoded is! Map || decoded['error_code'] == null) return null;
    final code = decoded['error_code'].toString();
    if (code == '401') {
      return 'Chave Soniox inválida. Verifique a chave do perfil.';
    }
    final details = decoded['error_message'] ?? decoded['error_type'] ?? '';
    return 'Erro Soniox ($code): $details';
  }
}
