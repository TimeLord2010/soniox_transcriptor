import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/providers/history_provider.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

import '../../helpers/database.dart';
import '../../helpers/prefs.dart';

void main() {
  late ProviderContainer container;
  late TranscriptionRepository repo;

  setUp(() async {
    await setUpPrefs();
    setUpDatabase();
    repo = GetIt.I.get<TranscriptionRepository>();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownGetIt();
  });

  TranscriptionRecord recordAt(int minute, String text) {
    return TranscriptionRecord(
      finalText: text,
      nonFinalText: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(minute * 60000),
    );
  }

  test('banco vazio vira histórico vazio', () {
    final state = container.read(historyProvider);
    expect(state.items, isEmpty);
    expect(state.hasMore, isFalse);
  });

  test('primeira página é do mais novo para o mais antigo', () {
    repo.insert(recordAt(1, 'antiga'));
    repo.insert(recordAt(2, 'nova'));

    expect(container.read(historyProvider).items.map((r) => r.finalText), [
      'nova',
      'antiga',
    ]);
  });

  test('não relê o banco sozinho: precisa de invalidate', () {
    expect(container.read(historyProvider).items, isEmpty);
    repo.insert(recordAt(1, 'gravada depois'));
    expect(container.read(historyProvider).items, isEmpty);

    container.invalidate(historyProvider);

    final state = container.read(historyProvider);
    expect(state.items.single.finalText, 'gravada depois');
    expect(state.totals.totalChars, 14);
  });

  test('loadMore traz as próximas páginas até acabar', () {
    for (var i = 1; i <= kHistoryPageSize + 5; i++) {
      repo.insert(recordAt(i, 'r$i'));
    }

    final first = container.read(historyProvider);
    expect(first.items, hasLength(kHistoryPageSize));
    expect(first.hasMore, isTrue);

    container.read(historyProvider.notifier).loadMore();

    final all = container.read(historyProvider);
    expect(all.items, hasLength(kHistoryPageSize + 5));
    expect(all.items.last.finalText, 'r1');
    expect(all.hasMore, isFalse);
  });

  test('limpar o histórico e invalidar zera lista e totais', () {
    repo.insert(recordAt(1, 'antiga'));
    expect(container.read(historyProvider).items, hasLength(1));

    repo.deleteAll();
    container.invalidate(historyProvider);

    final state = container.read(historyProvider);
    expect(state.items, isEmpty);
    expect(state.totals.totalChars, 0);
  });
}
