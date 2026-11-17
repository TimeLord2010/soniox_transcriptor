import 'package:get_it/get_it.dart';
import 'package:riverpod/riverpod.dart';

import '../models/history_summary.dart';
import '../models/transcription_record.dart';
import '../repositories/transcription_repository.dart';

/// Quantos registros cada página do histórico traz.
const int kHistoryPageSize = 30;

class HistoryState {
  const HistoryState({
    required this.items,
    required this.hasMore,
    required this.totals,
  });

  final List<TranscriptionRecord> items;
  final bool hasMore;
  final HistoryTotals totals;
}

/// Histórico paginado (mais novos primeiro): começa com a primeira página e
/// [loadMore] traz as seguintes. `ref.invalidate` volta para a primeira página
/// e relê os totais.
class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier(this._repo, {this.pageSize = kHistoryPageSize})
    : super(_first(_repo, pageSize));

  final TranscriptionRepository _repo;
  final int pageSize;

  static HistoryState _first(TranscriptionRepository repo, int size) {
    final items = repo.page(limit: size);
    return HistoryState(
      items: items,
      hasMore: items.length == size,
      totals: repo.totals,
    );
  }

  void loadMore() {
    if (!state.hasMore) return;
    final next = _repo.page(limit: pageSize, offset: state.items.length);
    state = HistoryState(
      items: [...state.items, ...next],
      hasMore: next.length == pageSize,
      totals: _repo.totals,
    );
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((
  _,
) {
  return HistoryNotifier(GetIt.I.get<TranscriptionRepository>());
});
