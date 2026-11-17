import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/repositories/history_store_sqlite.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

import '../../helpers/database.dart';
import '../../helpers/prefs.dart';

void main() {
  late Database db;
  late TranscriptionRepository repo;

  setUp(() async {
    await setUpPrefs();
    db = setUpDatabase();
    repo = GetIt.I.get<TranscriptionRepository>();
  });

  tearDown(tearDownGetIt);

  /// Registro com `createdAt` derivado de [minute] para ordenar sem depender do
  /// relógio real.
  TranscriptionRecord recordAt(int minute, {String text = 'texto'}) {
    return TranscriptionRecord(
      finalText: text,
      nonFinalText: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(minute * 60000),
    );
  }

  group('insert', () {
    test('grava as três colunas', () {
      repo.insert(
        TranscriptionRecord(
          finalText: 'final',
          nonFinalText: 'parcial',
          createdAt: DateTime.fromMillisecondsSinceEpoch(5000),
        ),
      );

      final row = db.select('SELECT * FROM transcriptions').single;
      expect(row['final_text'], 'final');
      expect(row['non_final_text'], 'parcial');
      expect(row['created_at'], 5000);
    });

    test('aceita final vazio quando há texto parcial', () {
      repo.insert(
        TranscriptionRecord(
          finalText: '',
          nonFinalText: 'parcial',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );

      expect(repo.getAll().single.finalText, '');
    });

    test('sessão sem texto (só custo) fica fora da lista', () {
      repo.insert(recordAt(1, text: ''));

      expect(repo.getAll(), isEmpty);
    });
  });

  group('getAll', () {
    test('sem registros devolve lista vazia', () {
      expect(repo.getAll(), isEmpty);
    });

    test('devolve do mais novo para o mais antigo', () {
      repo.insert(recordAt(1, text: 'antigo'));
      repo.insert(recordAt(3, text: 'novo'));
      repo.insert(recordAt(2, text: 'meio'));

      expect(repo.getAll().map((r) => r.finalText), ['novo', 'meio', 'antigo']);
    });

    test('devolve os ids do banco e a data convertida', () {
      repo.insert(
        TranscriptionRecord(
          finalText: 'x',
          nonFinalText: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(9000),
        ),
      );

      final record = repo.getAll().single;
      expect(record.id, isNotNull);
      expect(record.createdAt, DateTime.fromMillisecondsSinceEpoch(9000));
    });
  });

  group('delete', () {
    test('remove só o registro pedido', () {
      repo.insert(recordAt(1, text: 'fica'));
      repo.insert(recordAt(2, text: 'sai'));
      final alvo = repo.getAll().firstWhere((r) => r.finalText == 'sai');

      repo.delete(alvo.id!);

      expect(repo.getAll().map((r) => r.finalText), ['fica']);
    });

    test('id inexistente não mexe em nada', () {
      repo.insert(recordAt(1));

      repo.delete(9999);

      expect(repo.getAll(), hasLength(1));
    });
  });

  test('deleteAll esvazia a tabela', () {
    repo.insert(recordAt(1));
    repo.insert(recordAt(2));

    repo.deleteAll();

    expect(repo.getAll(), isEmpty);
  });

  group('retenção de 90 dias', () {
    test('remove só o que passou de 90 dias', () {
      final now = DateTime(2026, 11, 17);
      TranscriptionRecord at(Duration age, String t) => TranscriptionRecord(
        finalText: t,
        nonFinalText: '',
        createdAt: now.subtract(age),
      );
      repo.insert(at(const Duration(days: 89), 'dentro'));
      repo.insert(at(const Duration(days: 91), 'fora'));
      expect(repo.getAll(), hasLength(2));

      final removed = repo.pruneExpired(now: now);

      expect(removed, 1);
      expect(repo.getAll().map((r) => r.finalText), ['dentro']);
      expect(repo.totals.totalChars, 6);
    });
  });

  test('page devolve páginas corretas', () {
    for (var i = 1; i <= 5; i++) {
      repo.insert(recordAt(i, text: 'r$i'));
    }

    expect(repo.page(limit: 2).map((r) => r.finalText), ['r5', 'r4']);
    expect(repo.page(limit: 2, offset: 2).map((r) => r.finalText), [
      'r3',
      'r2',
    ]);
    expect(repo.page(limit: 2, offset: 4).map((r) => r.finalText), ['r1']);
  });

  group('totais persistidos', () {
    test('atualizam em insert, delete e deleteAll', () {
      repo.insert(
        TranscriptionRecord(
          finalText: 'abcd',
          nonFinalText: 'ef',
          createdAt: DateTime.fromMillisecondsSinceEpoch(60000),
          audioDurationMs: 2000,
        ),
      );
      repo.insert(recordAt(2, text: 'xy'));
      expect(repo.totals.totalChars, 8);
      expect(repo.totals.audioMs, 2000);
      expect(repo.totals.recordsWithDuration, 1);
      expect(repo.totals.recordsWithoutDuration, 1);

      repo.delete(repo.getAll().firstWhere((r) => r.finalText == 'xy').id!);
      expect(repo.totals.totalChars, 6);
      expect(repo.totals.recordsWithoutDuration, 0);

      repo.deleteAll();
      expect(repo.totals.recordCount, 0);
      expect(repo.totals.totalChars, 0);
    });

    test('banco antigo sem tabela de totais é migrado uma vez', () {
      final old = sqlite3.openInMemory();
      old.execute(
        'CREATE TABLE transcriptions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'final_text TEXT NOT NULL, non_final_text TEXT NOT NULL, '
        'created_at INTEGER NOT NULL)',
      );
      old.execute(
        "INSERT INTO transcriptions (final_text, non_final_text, created_at) "
        "VALUES ('abc', 'de', 1000)",
      );

      final store = SqliteHistoryStore(old);

      expect(store.totals.totalChars, 5);
      expect(store.totals.recordsWithoutDuration, 1);
      // Reabrir lê a linha persistida em vez de recalcular.
      expect(SqliteHistoryStore(old).totals.totalChars, 5);
      final row = old.select('SELECT * FROM history_totals').single;
      expect(row['total_chars'], 5);
    });
  });
}
