import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/repositories/hotkey_listener.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:soniox_transcriptor/repositories/soniox_websocket_impl.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';
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
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<List<int>>? _recordStreamSubscription;
  StreamSubscription? _transcriptionSubscription;
  bool _isProcessing = false;
  late List<TranscriptionRecord> _history;

  @override
  void initState() {
    hotkeyListener.start();
    _history = GetIt.I.get<TranscriptionRepository>().getAll();
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
        Expanded(
          child: Column(
            spacing: 12,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _history.isEmpty ? null : _clearHistory,
                    child: const Text('Clear all'),
                  ),
                ],
              ),
              Expanded(
                child: _history.isEmpty
                    ? Center(
                        child: Text(
                          'No transcriptions yet',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final record = _history[index];
                          return _buildHistoryItem(record);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(TranscriptionRecord record) {
    final timeStr = _formatTime(record.createdAt);
    return Dismissible(
      key: ValueKey(record.id),
      onDismissed: (_) {
        GetIt.I.get<TranscriptionRepository>().delete(record.id!);
        setState(() {
          _history.removeWhere((r) => r.id == record.id);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: CupertinoColors.systemGrey4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              record.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: record.text));
                  },
                  child: const Icon(
                    CupertinoIcons.doc_on_doc,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return dt.toIso8601String();
  }

  void _clearHistory() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear all history?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              GetIt.I.get<TranscriptionRepository>().deleteAll();
              setState(() {
                _history.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
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
        setState(() {
          _history = GetIt.I.get<TranscriptionRepository>().getAll();
        });
        HotkeyListener.pasteText(textToPast);
      }
      current.disconnect();
      recorder.stop();
      _isProcessing = false;
      _updateSonioxInstance(apiKey: apiKey);
    };
  }
}
