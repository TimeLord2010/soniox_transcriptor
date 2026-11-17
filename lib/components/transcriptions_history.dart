import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../models/history_summary.dart';
import '../models/transcription_record.dart';
import '../providers/history_provider.dart';
import '../repositories/transcription_repository.dart';
import 'pages/transcription_detail_page.dart';
import 'styles/ui.dart';

class TranscriptionsHistory extends ConsumerWidget {
  const TranscriptionsHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Histórico',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _clearHistory(context, ref),
                child: const Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: CupertinoColors.label,
                ),
              ),
            ],
          ),
        ),
        if (history.isNotEmpty)
          _SummaryHeader(summary: HistorySummary.from(history)),
        Expanded(child: _content(ref, history)),
      ],
    );
  }

  Widget _content(WidgetRef ref, List<TranscriptionRecord> history) {
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'Sem transcrições',
          style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      itemCount: history.length,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      itemBuilder: (context, index) {
        return _HistoryItem(record: history[index]);
      },
    );
  }

  void _clearHistory(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
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
              ref.read(historyProvider.notifier).state = [];
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary});

  final HistorySummary summary;

  @override
  Widget build(BuildContext context) {
    final audio = summary.recordsWithDuration == 0
        ? '—'
        : formatDurationPt(summary.totalAudio);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: fieldDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stat('Caracteres', formatThousandsPtBr(summary.totalChars)),
              _stat('Duração', audio),
              _stat('Tempo salvo', formatDurationPt(summary.timeSaved)),
            ],
          ),
          if (summary.recordsWithoutDuration > 0 &&
              summary.recordsWithDuration > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Sem duração em ${summary.recordsWithoutDuration} '
              '${summary.recordsWithoutDuration == 1 ? 'transcrição antiga' : 'transcrições antigas'}',
              style: const TextStyle(
                fontSize: 11,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.record});

  final TranscriptionRecord record;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => TranscriptionDetailPage(record: record),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: fieldDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDateTime(record.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: record.text));
                  },
                  child: const Icon(
                    CupertinoIcons.doc_on_doc,
                    size: 16,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Data e hora do registro em pt-BR, no fuso do aparelho: 16/11/2026 19:23.
///
/// Antes saía o `toIso8601String()` cru (2026-11-16T19:23:05.123-0300), que é
/// formato de máquina. O `toLocal()` é explícito para o caso de o registro ter
/// vindo em UTC (importação do teclado).
String formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
