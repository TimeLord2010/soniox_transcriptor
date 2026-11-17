import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';

import '../../models/transcription_record.dart';
import '../styles/ui.dart';
import '../transcriptions_history.dart' show formatDateTime;

/// Página de uma transcrição do histórico: texto completo (selecionável) e
/// dados da gravação (data, duração do áudio e quantidade de caracteres).
class TranscriptionDetailPage extends StatelessWidget {
  const TranscriptionDetailPage({super.key, required this.record});

  final TranscriptionRecord record;

  @override
  Widget build(BuildContext context) {
    final text = record.text;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Transcrição'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          child: const Icon(CupertinoIcons.doc_on_doc, size: 20),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: fieldDecoration(),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Criada em',
                    value: formatDateTime(record.createdAt),
                  ),
                  _InfoRow(
                    label: 'Duração do áudio',
                    value: formatAudioDuration(record.audioDurationMs),
                  ),
                  _InfoRow(label: 'Caracteres', value: '${text.length}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: fieldDecoration(),
              child: SelectableText(text, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// `mm:ss` (ou `h:mm:ss` a partir de 1h); "—" quando a duração não foi
/// guardada (registros antigos).
String formatAudioDuration(int? ms) {
  if (ms == null) return '—';
  final total = Duration(milliseconds: ms).inSeconds;
  String two(int v) => v.toString().padLeft(2, '0');
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
