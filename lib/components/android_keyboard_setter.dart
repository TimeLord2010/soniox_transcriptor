import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'styles/ui.dart';

/// Status do teclado de ditado no Android, lido do sistema (não do app): o
/// teclado é um service do sistema, e quem sabe se ele está habilitado/selecionado
/// é o `Settings.Secure`, via a Activity (`android/.../MainActivity.kt`).
class KeyboardStatus {
  const KeyboardStatus({required this.enabled, required this.selected});

  final bool enabled;
  final bool selected;

  static const unknown = KeyboardStatus(enabled: false, selected: false);
}

/// Seção "Teclado Android" na tela Início: liga o teclado no sistema e mostra
/// por que ele ainda não está em uso.
///
/// Só aparece no Android — no macOS e no web o teclado não existe, e um bloco
/// morto na tela é ruído (o app não tem bloco de recurso por plataforma).
class AndroidKeyboardSetter extends StatefulWidget {
  const AndroidKeyboardSetter({super.key});

  @override
  State<AndroidKeyboardSetter> createState() => _AndroidKeyboardSetterState();
}

class _AndroidKeyboardSetterState extends State<AndroidKeyboardSetter>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('soniox/keyboard');

  KeyboardStatus _status = KeyboardStatus.unknown;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O usuário sai para as configurações do sistema e volta: relê o estado
    // em vez de deixar a tela mentindo sobre o teclado.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('status');
      if (!mounted) return;
      setState(() {
        _status = KeyboardStatus(
          enabled: result?['enabled'] == true,
          selected: result?['selected'] == true,
        );
        _busy = false;
      });
    } on PlatformException catch (e) {
      debugPrint('[AndroidKeyboardSetter] status falhou: $e');
      if (!mounted) return;
      setState(() => _busy = false);
    } on MissingPluginException catch (e) {
      // Rodando o Flutter sem a Activity nova (hot restart antigo): sem estado,
      // mas sem quebrar a tela.
      debugPrint('[AndroidKeyboardSetter] canal ausente: $e');
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    await _channel.invokeMethod<void>('openSettings');
  }

  Future<void> _showPicker() async {
    await _channel.invokeMethod<void>('showPicker');
    // O seletor abre sobre o app; quando fecha, o estado pode ter mudado.
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Teclado Android', style: sectionLabelStyle),
        const Gap(kLabelSpacing),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: fieldDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _status.selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.keyboard,
                    size: 18,
                    color: _status.selected
                        ? CupertinoColors.activeGreen
                        : CupertinoColors.secondaryLabel,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      _statusLabel(),
                      key: const ValueKey('android-keyboard-status'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Row(
                children: [
                  Expanded(
                    child: _action(
                      key: const ValueKey('android-keyboard-enable'),
                      label: 'Ativar teclado',
                      filled: !_status.enabled,
                      onPressed: _openSettings,
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: _action(
                      key: const ValueKey('android-keyboard-picker'),
                      label: 'Escolher teclado',
                      filled: _status.enabled && !_status.selected,
                      onPressed: _showPicker,
                    ),
                  ),
                ],
              ),
              const Gap(10),
              const Text(
                'O ditado escreve no campo do app em foco, com os idiomas, '
                'termos, contexto e tradução do perfil ativo. Este teclado é '
                'de ditado: o botão "abc" devolve o teclado normal.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel() {
    if (_busy) return 'Verificando…';
    if (_status.selected) return 'Teclado Soniox em uso.';
    if (_status.enabled) {
      return 'Habilitado. Escolha "Soniox ditado" como teclado atual.';
    }
    return 'Desligado. Ative nas configurações de teclado do sistema.';
  }

  Widget _action({
    required Key key,
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: filled
          ? CupertinoColors.activeBlue
          : CupertinoColors.systemBackground,
      borderRadius: BorderRadius.circular(8),
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: filled ? CupertinoColors.white : CupertinoColors.label,
        ),
      ),
    );
  }
}
