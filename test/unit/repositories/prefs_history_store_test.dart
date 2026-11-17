import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/repositories/history_store_prefs.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

import '../../helpers/prefs.dart';

/// O store web (SharedPreferences/localStorage) é o caminho que substitui o
/// SQLite fora do macOS/Android — o contrato é o mesmo e precisa ser provado
/// aqui, já que `flutter test` roda no host e não no browser.
void main() {
  late PrefsHistoryStore store;

  setUp(() async {
    await setUpPrefs();
    store = PrefsHistoryStore();
    await store.load();
  });

  tearDown(tearDownGetIt);

  TranscriptionRecord recordAt(int minute, {String text = 'texto'}) {
    return TranscriptionRecord(
      finalText: text,
      nonFinalText: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(minute * 60000),
    );
  }

  test('começa vazio quando não há nada salvo', () {
    expect(store.getAll(), isEmpty);
  });

  test(
    'insert atribui id e getAll devolve do mais novo para o mais antigo',
    () {
      store.insert(recordAt(1, text: 'antigo'));
      store.insert(recordAt(3, text: 'novo'));
      store.insert(recordAt(2, text: 'meio'));

      final all = store.getAll();
      expect(all.map((r) => r.finalText), ['novo', 'meio', 'antigo']);
      expect(all.every((r) => r.id != null), isTrue);
      expect(all.map((r) => r.id).toSet(), hasLength(3));
    },
  );

  test('persiste em JSON e uma instância nova recarrega tudo', () async {
    store.insert(recordAt(1, text: 'primeiro'));
    store.insert(recordAt(2, text: 'segundo'));
    await pumpEventQueue();

    final reloaded = PrefsHistoryStore();
    await reloaded.load();

    expect(reloaded.getAll().map((r) => r.finalText), ['segundo', 'primeiro']);
    // Ids continuam de onde pararam: gravar depois de recarregar não colide.
    reloaded.insert(recordAt(3, text: 'terceiro'));
    final ids = reloaded.getAll().map((r) => r.id).toList();
    expect(ids.toSet(), hasLength(3));
  });

  test('delete remove só o registro pedido', () {
    store.insert(recordAt(1, text: 'fica'));
    store.insert(recordAt(2, text: 'sai'));
    final alvo = store.getAll().firstWhere((r) => r.finalText == 'sai');

    store.delete(alvo.id!);

    expect(store.getAll().map((r) => r.finalText), ['fica']);
  });

  test('deleteAll esvazia a lista', () {
    store.insert(recordAt(1));
    store.insert(recordAt(2));

    store.deleteAll();

    expect(store.getAll(), isEmpty);
  });

  test('page devolve páginas do mais novo para o mais antigo', () {
    for (var i = 1; i <= 5; i++) {
      store.insert(recordAt(i, text: 'r$i'));
    }

    expect(store.page(limit: 2).map((r) => r.finalText), ['r5', 'r4']);
    expect(store.page(limit: 2, offset: 2).map((r) => r.finalText), [
      'r3',
      'r2',
    ]);
    expect(store.page(limit: 2, offset: 4).map((r) => r.finalText), ['r1']);
    expect(store.page(limit: 2, offset: 6), isEmpty);
  });

  test(
    'totais: insert, delete, prune e limpar; persistem entre cargas',
    () async {
      store.insert(recordAt(1, text: 'aaaa'));
      store.insert(
        TranscriptionRecord(
          finalText: 'bb',
          nonFinalText: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(2 * 60000),
          audioDurationMs: 5000,
        ),
      );
      expect(store.totals.totalChars, 6);
      expect(store.totals.audioMs, 5000);
      expect(store.totals.recordsWithDuration, 1);
      expect(store.totals.recordsWithoutDuration, 1);
      await pumpEventQueue();

      final reloaded = PrefsHistoryStore();
      await reloaded.load();
      expect(reloaded.totals.totalChars, 6);

      // Poda tira o registro de 1 min (cutoff em 90 s).
      expect(
        reloaded.pruneOlderThan(DateTime.fromMillisecondsSinceEpoch(90000)),
        1,
      );
      expect(reloaded.totals.totalChars, 2);
      expect(reloaded.totals.recordsWithoutDuration, 0);

      reloaded.delete(reloaded.getAll().single.id!);
      expect(reloaded.totals.totalChars, 0);
      expect(reloaded.totals.audioMs, 0);

      reloaded.insert(recordAt(3, text: 'x'));
      reloaded.deleteAll();
      expect(reloaded.totals.totalChars, 0);
      expect(reloaded.totals.recordCount, 0);
    },
  );

  test('migração: sem totais salvos calcula uma vez dos registros', () async {
    store.insert(recordAt(1, text: 'abc'));
    await pumpEventQueue();
    await currentPrefs.remove(PrefsHistoryStore.totalsKey);

    final reloaded = PrefsHistoryStore();
    await reloaded.load();

    expect(reloaded.totals.totalChars, 3);
    expect(reloaded.totals.recordsWithoutDuration, 1);
  });

  test('JSON corrompido não derruba o app: começa vazio', () async {
    await currentPrefs.setString(
      PrefsHistoryStore.storageKey,
      '{isso não é json',
    );

    final quebrado = PrefsHistoryStore();
    await quebrado.load();

    expect(quebrado.getAll(), isEmpty);
    // O conteúdo antigo é preservado para diagnóstico.
    expect(currentPrefs.getString(PrefsHistoryStore.storageKey), isNotNull);
  });

  test('JSON de formato errado também é tratado', () async {
    await currentPrefs.setString(
      PrefsHistoryStore.storageKey,
      jsonEncode({'não': 'é lista'}),
    );

    final quebrado = PrefsHistoryStore();
    await quebrado.load();

    expect(quebrado.getAll(), isEmpty);
  });

  group('com o repositório', () {
    test('retenção de 90 dias remove só o que passou do limite', () {
      final repo = TranscriptionRepository(store: store);
      final now = DateTime(2026, 11, 17);
      TranscriptionRecord at(DateTime d, String t) =>
          TranscriptionRecord(finalText: t, nonFinalText: '', createdAt: d);
      repo.insert(at(now.subtract(const Duration(days: 91)), 'velho'));
      repo.insert(at(now.subtract(const Duration(days: 89)), 'quase'));
      repo.insert(at(now, 'hoje'));

      // Insert já podeu o de 91 dias (contado a partir do registro novo).
      expect(repo.getAll().map((r) => r.finalText), ['hoje', 'quase']);

      repo.pruneExpired(now: now.add(const Duration(days: 2)));
      expect(repo.getAll().map((r) => r.finalText), ['hoje']);
      expect(repo.totals.totalChars, 4);
    });
  });
}
