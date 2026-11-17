import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/models/usage_cost.dart';
import 'package:soniox_transcriptor/repositories/history_store.dart';
import 'package:soniox_transcriptor/repositories/history_store_prefs.dart';
import 'package:soniox_transcriptor/repositories/history_store_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';

TranscriptionRecord rec(String text, String? ref) => TranscriptionRecord(
  finalText: text,
  nonFinalText: '',
  createdAt: DateTime.now(),
  audioDurationMs: 4000,
  clientReferenceId: ref,
);

/// Mesmo roteiro nos dois stores: custo chegando atualiza os totais.
void cases(String name, Future<HistoryStore> Function() open) {
  group(name, () {
    test(
      'custo que chega atualiza totais; sem texto fica fora da lista',
      () async {
        final store = await open();
        store.insert(rec('olá', 'a'));
        store.insert(rec('', 'vazia'));
        store.insert(rec('antigo', null));

        expect(store.getAll().length, 2);
        expect(store.totals.pendingCost, 2);
        expect(store.totals.noCost, 1);
        expect(store.pendingCosts().map((r) => r.clientReferenceId).toSet(), {
          'a',
          'vazia',
        });

        store.applyCost('a', const UsageCost(costE10: 1580000));
        store.applyCost('vazia', const UsageCost(costE10: 420000));
        expect(store.totals.costE10, 2000000);
        expect(store.totals.pendingCost, 0);
        expect(store.totals.emptySessionsWithCost, 1);
        expect(store.getAll().length, 2);
        expect(store.pendingCosts(), isEmpty);
      },
    );

    test('não encontrado vira "sem custo"; sessão vazia some', () async {
      final store = await open();
      store.insert(rec('olá', 'a'));
      store.insert(rec('', 'vazia'));
      store.applyCost('a', null);
      store.applyCost('vazia', null);
      expect(store.totals.pendingCost, 0);
      expect(store.totals.noCost, 1);
      expect(store.totals.costE10, 0);
      expect(store.getAll().single.costState, CostState.unavailable);
      expect(store.pendingCosts(), isEmpty);
    });
  });
}

void main() {
  cases('sqlite', () async => SqliteHistoryStore(sqlite3.openInMemory()));
  cases('prefs', () async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.I.reset();
    GetIt.I.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
    final store = PrefsHistoryStore();
    await store.load();
    return store;
  });
}
