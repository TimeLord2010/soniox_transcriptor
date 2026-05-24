import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/protocols/show_toast.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static const _hotkeyChannel = MethodChannel('hotkey_plugin');

  @override
  void initState() {
    super.initState();
    _hotkeyChannel.setMethodCallHandler(_onMethodCall);
    _hotkeyChannel.invokeMethod('start');
  }

  @override
  void dispose() {
    _hotkeyChannel.invokeMethod('stop');
    _hotkeyChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onHotkeyPressed':
        _onGlobalHotkeyPressed();
      case 'onHotkeyReleased':
        _onGlobalHotkeyReleased();
    }
  }

  void _onGlobalHotkeyPressed() {
    if (mounted) {
      showToast(context, 'Global hotkey triggered!');
    }
    print('global key pressed');
  }

  void _onGlobalHotkeyReleased() {
    if (mounted) {
      showToast(context, 'Global hotkey released!');
    }
    print('global key released');
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
          child: Column(spacing: 20, children: [ApiKeySetter()]),
        ),
      ),
    );
  }
}
