import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/models/usage_cost.dart';
import 'package:soniox_transcriptor/modules/cost_sync.dart';
import 'package:soniox_transcriptor/repositories/history_store_sqlite.dart';
import 'package:soniox_transcriptor/repositories/usage_logs_repository.dart';
import 'package:sqlite3/sqlite3.dart';

class _FakeLogs extends UsageLogsRepository {
  _FakeLogs(this.logs);
  final Map<String, UsageCost> logs;
  bool fail = false;

  @override
  Future<Map<String, UsageCost>> fetch(
    String apiKey, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (fail) throw UsageLogsException('sem rede');
    return logs;
  }
}

void main() {
  final now = DateTime(2026, 11, 17, 12);

  TranscriptionRecord rec(String ref, Duration age) => TranscriptionRecord(
    finalText: 'texto',
    nonFinalText: '',
    createdAt: now.subtract(age),
    clientReferenceId: ref,
  );

  test('grava o custo achado, ignora o que ainda não apareceu', () async {
    final store = SqliteHistoryStore(sqlite3.openInMemory());
    store.insert(rec('a', const Duration(minutes: 1)));
    store.insert(rec('b', const Duration(minutes: 1)));
    var notified = 0;
    final sync = CostSync(
      store: store,
      repository: _FakeLogs({'a': const UsageCost(costE10: 1580000)}),
      apiKeys: () => ['k'],
      now: () => now,
      onChanged: () => notified++,
    );
    await sync.reconcile();
    sync.dispose();

    expect(store.totals.costE10, 1580000);
    expect(store.totals.pendingCost, 1);
    expect(notified, 1);
  });

  test(
    'passadas 24 h sem aparecer vira "sem custo"; sem rede não desiste',
    () async {
      final store = SqliteHistoryStore(sqlite3.openInMemory());
      store.insert(rec('velha', const Duration(hours: 25)));
      final logs = _FakeLogs({})..fail = true;
      final sync = CostSync(
        store: store,
        repository: logs,
        apiKeys: () => ['k'],
        now: () => now,
      );
      await sync.reconcile();
      expect(
        store.totals.pendingCost,
        1,
        reason: 'falha de rede não é "não achou"',
      );

      logs.fail = false;
      await sync.reconcile();
      sync.dispose();
      expect(store.totals.pendingCost, 0);
      expect(store.totals.noCost, 1);
    },
  );
}
