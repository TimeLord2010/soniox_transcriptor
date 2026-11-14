import 'package:flutter/cupertino.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';

/// Campo de texto longo da aba Sandbox (transcrição e tradução).
///
/// `expands` exige minLines/maxLines nulos: a caixa cresce com a aba e o texto
/// rola por dentro dela quando passa da altura. `readOnly` é a caixa da
/// tradução — quem escreve nela é o Soniox.
class SandboxTextField extends StatelessWidget {
  const SandboxTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.placeholder,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      expands: true,
      minLines: null,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      placeholder: placeholder,
      padding: const EdgeInsets.all(12),
      decoration: fieldDecoration(),
      style: const TextStyle(fontSize: 14),
    );
  }
}
