import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/modules/keyboard_history_importer.dart';
import 'package:soniox_transcriptor/repositories/history_store.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

import '../../helpers/database.dart';
import '../../helpers/prefs.dart';

/// Repositório que falha no N-ésimo insert (1-based).
class _FailingRepo implements TranscriptionRepository {
  final TranscriptionRepository inner;
  final int failOn;
  int calls = 0;
  _FailingRepo(this.inner, this.failOn);

  @override
  void insert(TranscriptionRecord record) {
    calls++;
    if (calls == failOn) throw StateError('db down');
    inner.insert(record);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory base;
  late Directory box;
  late TranscriptionRepository repo;
  late KeyboardHistoryImporter importer;

  String entry(String text, int ms) =>
      jsonEncode({'final_text': text, 'created_at': ms});

  File put(String name, String content) =>
      File('${box.path}/$name')..writeAsStringSync(content);

  setUp(() async {
    await setUpPrefs();
    setUpDatabase();
    repo = GetIt.I.get<TranscriptionRepository>();
    base = await Directory.systemTemp.createTemp('kbd_history_test');
    box = Directory('${base.path}/${KeyboardHistoryImporter.dirName}')
      ..createSync();
    importer = KeyboardHistoryImporter(
      directory: () async => base,
      enabled: true,
    );
  });

  tearDown(() async {
    await tearDownGetIt();
    await base.delete(recursive: true);
  });

  test('imports files, deletes them, newest first', () async {
    put('1000-a.json', entry('antigo', 1000));
    put('2000-b.json', entry('novo', 2000));

    expect(await importer.run(), 2);

    final all = repo.getAll();
    expect(all.map((r) => r.finalText), ['novo', 'antigo']);
    expect(all.first.createdAt.millisecondsSinceEpoch, 2000);
    expect(all.first.nonFinalText, '');
    expect(box.listSync(), isEmpty);
  });

  test('malformed files are deleted without inserting', () async {
    put('1-a.json', 'not json');
    put('2-b.json', '[1,2]');
    put('3-c.json', '{"final_text":1,"created_at":2}');
    put('4-d.json', entry('  ', 6));
    put('5-e.json', entry('ok', 5));

    expect(await importer.run(), 1);
    expect(repo.getAll().map((r) => r.finalText), ['ok']);
    expect(box.listSync(), isEmpty);
  });

  test('carries client_reference_id; old entries stay without it', () async {
    var notified = 0;
    importer = KeyboardHistoryImporter(
      directory: () async => base,
      enabled: true,
      onReferencesImported: () => notified++,
    );
    put('1-a.json', jsonEncode({'final_text': 'velho', 'created_at': 1}));
    put(
      '2-b.json',
      jsonEncode({
        'final_text': 'novo',
        'created_at': 2,
        'client_reference_id': 'ref-123',
      }),
    );

    expect(await importer.run(), 2);

    final byText = {for (final r in repo.getAll()) r.finalText: r};
    expect(byText['novo']!.clientReferenceId, 'ref-123');
    expect(byText['novo']!.costState, CostState.pending);
    expect(byText['velho']!.clientReferenceId, isNull);
    expect(byText['velho']!.costState, CostState.unavailable);
    expect(notified, 1);
  });

  test(
    'empty text is imported only with a reference (hidden record)',
    () async {
      put(
        '1-a.json',
        jsonEncode({
          'final_text': '',
          'created_at': 1,
          'client_reference_id': 'ref-empty',
        }),
      );
      put('2-b.json', entry('', 2));

      expect(await importer.run(), 1);

      expect(repo.getAll(), isEmpty); // fora da lista
      final pending = GetIt.I.get<HistoryStore>().pendingCosts();
      expect(pending.single.isHidden, isTrue);
      expect(pending.single.clientReferenceId, 'ref-empty');
      expect(box.listSync(), isEmpty);
    },
  );

  test('missing dir returns 0', () async {
    box.deleteSync(recursive: true);
    expect(await importer.run(), 0);
  });

  test('.tmp files are ignored and kept', () async {
    final tmp = put('9-x.tmp', entry('parcial', 9));
    put('1-a.json', entry('a', 1));

    expect(await importer.run(), 1);
    expect(tmp.existsSync(), isTrue);
    expect(repo.getAll().length, 1);
  });

  test('insert failure stops; rerun totals 3, not 4', () async {
    put('1-a.json', entry('a', 1));
    put('2-b.json', entry('b', 2));
    put('3-c.json', entry('c', 3));
    final shared = _FailingRepo(repo, 2);
    final failing = KeyboardHistoryImporter(
      directory: () async => base,
      repository: () => shared,
      enabled: true,
    );

    expect(await failing.run(), 1);
    expect(repo.getAll().length, 1);
    expect(box.listSync().length, 2);

    expect(await importer.run(), 2);
    expect(repo.getAll().length, 3);
    expect(box.listSync(), isEmpty);
  });

  test(
    'keeps every imported record (retention is by age, not count)',
    () async {
      for (var i = 0; i < 120; i++) {
        put(
          '${(i * 1000).toString().padLeft(8, '0')}-x.json',
          entry('t$i', i * 1000),
        );
      }

      await importer.run();

      final all = repo.getAll();
      expect(all.length, 120);
      expect(all.first.finalText, 't119');
    },
  );

  test('concurrent runs share one execution', () async {
    put('1-a.json', entry('a', 1));

    final results = await Future.wait([importer.run(), importer.run()]);

    expect(results, [1, 1]);
    expect(repo.getAll().length, 1);
  });

  test('disabled importer is a no-op', () async {
    final f = put('1-a.json', entry('a', 1));
    final off = KeyboardHistoryImporter(
      directory: () async => base,
      enabled: false,
    );

    expect(await off.run(), 0);
    expect(f.existsSync(), isTrue);
  });
}
