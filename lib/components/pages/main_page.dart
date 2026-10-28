import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/components/context_text_setter.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/components/language_picker.dart';
import 'package:soniox_transcriptor/components/profile_selector.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';
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
  StreamSubscription<SonioxError>? _errorSubscription;
  StreamSubscription<String>? _recorderErrorSubscription;
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
    // mount more than once (a theme/shell rebuild replaces the subtree), and
    // calling the static stop() here would tear down the monitor that a newer,
    // still-alive MainPage just registered. Let it live for the app's
    // lifetime; the OS reclaims it on exit.
    _sandboxController.dispose();
    _sandboxFocusNode.dispose();
    _recorderErrorSubscription?.cancel();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The session depends on the active profile (key, terms, languages and
    // context), so rebuild it when either the key or the profile changes.
    // Both can fire in the same frame on a switch; coalesce into one rebuild.
    ref.listen(apiKeyProvider, (_, _) => _scheduleSessionRebuild());
    ref.listen(activeProfileIdProvider, (_, _) => _scheduleSessionRebuild());
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Stack(
        children: [
          Positioned.fill(child: _content()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CupertinoTabBar(
              currentIndex: currentPage,
              onTap: (value) {
                setState(() => currentPage = value);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.house),
                  activeIcon: Icon(CupertinoIcons.house_fill),
                  label: 'Início',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.clock),
                  activeIcon: Icon(CupertinoIcons.clock_fill),
                  label: 'Histórico',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return switch (currentPage) {
      0 => _homePage(),
      1 => const TranscriptionsHistory(),
      _ => const SizedBox.shrink(),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: kSectionSpacing,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: CupertinoColors.systemOrange,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Este perfil não tem chave Soniox. O atalho não vai gravar '
              'até que uma chave seja definida.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Column _sandbox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sandbox', style: sectionLabelStyle),
        const SizedBox(height: kLabelSpacing),
        CupertinoTextField(
          controller: _sandboxController,
          focusNode: _sandboxFocusNode,
          minLines: 5,
          maxLines: 5,
          padding: const EdgeInsets.all(12),
          decoration: fieldDecoration(),
          style: const TextStyle(fontSize: 14),
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
    _recorderErrorSubscription?.cancel();

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
        if (!_isProcessing || !identical(current, soniox)) {
          // The key was released while the capture was being (re)started.
          await recorder.stop();
          return;
        }
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

    // The capture can fail (or die silently) without touching Soniox: show it
    // in the overlay instead of leaving the user with an empty transcription.
    _recorderErrorSubscription = recorder.errors.listen((message) {
      if (!_isProcessing || sessionError != null) {
        return;
      }
      sessionError = message;
      HotkeyListener.showError(message);
      _recordStreamSubscription?.cancel();
    });

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

      _errorSubscription?.cancel();
      _errorSubscription = current.errors.listen((sonioxError) {
        if (sessionError != null) return;
        final error = _describeSonioxError(sonioxError);
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

  String _describeSonioxError(SonioxError error) {
    return switch (error.code) {
      401 => 'Chave Soniox inválida. Verifique a chave do perfil.',
      // vit_soniox reports a failed connection with code 0.
      0 => 'Não foi possível conectar à Soniox: ${error.message}',
      _ => 'Erro Soniox (${error.code}): ${error.message}',
    };
  }
}
