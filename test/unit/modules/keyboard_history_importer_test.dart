import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/modules/keyboard_history_importer.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

import '../../helpers/database.dart';
import '../../helpers/prefs.dart';

void main() {
  late Directory dir;
  late TranscriptionRepository repo;
  late KeyboardHistoryImporter importer;

  File outbox() => File('${dir.path}/${KeyboardHistoryImporter.outboxName}');
  File importing() =>
      File('${dir.path}/${KeyboardHistoryImporter.importingName}');

  String line(String text, int ms) =>
      jsonEncode({'final_text': text, 'created_at': ms});

  setUp(() async {
    await setUpPrefs();
    setUpDatabase();
    repo = GetIt.I.get<TranscriptionRepository>();
    dir = await Directory.systemTemp.createTemp('kbd_history_test');
    importer = KeyboardHistoryImporter(
      directory: () async => dir,
      enabled: true,
    );
  });

  tearDown(() async {
    await tearDownGetIt();
    await dir.delete(recursive: true);
  });

  test('imports lines, deletes the file, newest first', () async {
    outbox().writeAsStringSync(
      '${line('antigo', 1000)}\n${line('novo', 2000)}\n',
    );

    expect(await importer.run(), 2);

    final all = repo.getAll();
    expect(all.map((r) => r.finalText), ['novo', 'antigo']);
    expect(all.first.createdAt.millisecondsSinceEpoch, 2000);
    expect(all.first.nonFinalText, '');
    expect(outbox().existsSync(), isFalse);
    expect(importing().existsSync(), isFalse);
  });

  test('skips malformed and blank lines', () async {
    outbox().writeAsStringSync(
      'not json\n\n${line('ok', 5)}\n{"final_text":1,"created_at":2}\n'
      '[1,2]\n${line('  ', 6)}\n',
    );

    expect(await importer.run(), 1);
    expect(repo.getAll().map((r) => r.finalText), ['ok']);
  });

  test('imports a leftover .importing first, then the outbox', () async {
    importing().writeAsStringSync('${line('sobra', 10)}\n');
    outbox().writeAsStringSync('${line('novo', 20)}\n');

    expect(await importer.run(), 2);
    expect(repo.getAll().map((r) => r.finalText), ['novo', 'sobra']);
    expect(importing().existsSync(), isFalse);
    expect(outbox().existsSync(), isFalse);
  });

  test('no file: nothing happens', () async {
    expect(await importer.run(), 0);
    expect(repo.getAll(), isEmpty);
  });

  test('keeps the .importing file when an insert fails', () async {
    outbox().writeAsStringSync('${line('a', 1)}\n');
    final failing = KeyboardHistoryImporter(
      directory: () async => dir,
      repository: () => throw StateError('db down'),
      enabled: true,
    );

    expect(await failing.run(), 0);
    expect(importing().existsSync(), isTrue);

    // Próxima tentativa (banco de volta) recupera.
    expect(await importer.run(), 1);
    expect(importing().existsSync(), isFalse);
  });

  test('respects the 100-record cap', () async {
    final lines = [for (var i = 0; i < 120; i++) line('t$i', i * 1000)];
    outbox().writeAsStringSync('${lines.join('\n')}\n');

    await importer.run();

    final all = repo.getAll();
    expect(all.length, TranscriptionRepository.maxRecords);
    expect(all.first.finalText, 't119');
  });

  test('concurrent runs share one execution', () async {
    outbox().writeAsStringSync('${line('a', 1)}\n');

    final results = await Future.wait([importer.run(), importer.run()]);

    expect(results, [1, 1]);
    expect(repo.getAll().length, 1);
  });

  test('disabled importer is a no-op', () async {
    outbox().writeAsStringSync('${line('a', 1)}\n');
    final off = KeyboardHistoryImporter(
      directory: () async => dir,
      enabled: false,
    );

    expect(await off.run(), 0);
    expect(outbox().existsSync(), isTrue);
  });
}
