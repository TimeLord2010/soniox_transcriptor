import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../models/transcription_record.dart';
import '../providers/history_provider.dart';
import '../repositories/transcription_repository.dart';
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

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.record});

  final TranscriptionRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                formatTime(record.createdAt),
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
    );
  }
}

String formatTime(DateTime dt) => dt.toIso8601String();
