import 'package:flutter/cupertino.dart';
import 'package:record/record.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
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

  List<InputDevice> _devices = [];
  InputDevice? _selectedDevice;

  @override
  void initState() {
    hotkeyListener.start();
    recorder.listInputDevices().then((_) {
      setState(() {
        _devices = recorder.devices;
        _selectedDevice = recorder.selectedDevice;
      });
    });
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            spacing: 20,
            children: [
              ApiKeySetter(
                onApiKeyChanged: (value) {
                  _updateSonioxInstance(apiKey: value ?? '');
                },
              ),
              _buildDeviceSelector(context),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: Widgets

  Widget _buildDeviceSelector(BuildContext context) {
    final label = _selectedDevice?.label ?? 'Default';
    return Row(
      children: [
        const Text('Input device'),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _devices.isEmpty ? null : () => _showDevicePicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.chevron_up_chevron_down, size: 14),
            ],
          ),
        ),
      ],
    );
  }

  void _showDevicePicker(BuildContext context) {
    final initialIndex = _selectedDevice == null
        ? 0
        : _devices.indexWhere((d) => d.id == _selectedDevice!.id).clamp(0, _devices.length - 1);
    var pickerIndex = initialIndex;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => Container(
        height: 216,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(initialItem: initialIndex),
          itemExtent: 36,
          onSelectedItemChanged: (i) => pickerIndex = i,
          children: _devices.map((d) => Center(child: Text(d.label))).toList(),
        ),
      ),
    ).then((_) {
      final picked = _devices[pickerIndex];
      setState(() => _selectedDevice = picked);
      recorder.selectedDevice = picked;
    });
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
      debugPrint('Final Transcription: ${buffer.toString()}');
      debugPrint('Non final transcription: $nonFinal');
      current.disconnect();
      recorder.stop();
      _updateSonioxInstance();
    };
  }
}
