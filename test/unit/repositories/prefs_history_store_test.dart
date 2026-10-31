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

  test('deleteOldest descarta os mais antigos', () {
    for (var i = 1; i <= 5; i++) {
      store.insert(recordAt(i, text: 'r$i'));
    }

    store.deleteOldest(2);

    expect(store.getAll().map((r) => r.finalText), ['r5', 'r4', 'r3']);
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
    test('guarda no máximo 100 registros, descartando os mais antigos', () {
      final repo = TranscriptionRepository(store: store);
      for (var i = 1; i <= 101; i++) {
        repo.insert(recordAt(i, text: 'r$i'));
      }

      final all = repo.getAll();
      expect(all, hasLength(TranscriptionRepository.maxRecords));
      expect(all.any((r) => r.finalText == 'r1'), isFalse);
      expect(all.first.finalText, 'r101');
    });
  });
}
