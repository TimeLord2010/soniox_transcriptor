import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:soniox_transcriptor/components/styles/glass_config.dart';

import '../models/transcription_record.dart';
import '../providers/history_provider.dart';
import '../repositories/transcription_repository.dart';

class TranscriptionsHistory extends ConsumerWidget {
  const TranscriptionsHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<TranscriptionRecord> history = ref.watch(historyProvider);
    return Stack(
      children: [
        Positioned.fill(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: _content(ref, history),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: GlassContainer(
            settings: glassSettings,
            quality: .premium,
            useOwnLayer: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                'Histórico',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: GlassButton(
            onTap: () {
              _clearHistory(context, ref);
            },
            useOwnLayer: true,
            settings: glassSettings,
            quality: .premium,
            icon: Icon(Icons.cleaning_services, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _content(WidgetRef ref, List<TranscriptionRecord> history) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          'Sem transcrições',
          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      itemCount: history.length,
      padding: EdgeInsets.fromLTRB(10, 70, 10, 100),
      itemBuilder: (context, index) {
        final record = history[index];
        return _buildHistoryItem(ref, record);
      },
    );
  }

  Widget _buildHistoryItem(WidgetRef ref, TranscriptionRecord record) {
    final timeStr = _formatTime(record.createdAt);
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.systemGrey4),
        borderRadius: BorderRadius.circular(8),
        color: const Color.fromARGB(255, 240, 240, 240),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            record.text,
            maxLines: 5,
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
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: record.text));
                },
                child: const Icon(CupertinoIcons.doc_on_doc, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return dt.toIso8601String();
  }

  // MARK: Events

  void _clearHistory(BuildContext context, WidgetRef ref) {
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
