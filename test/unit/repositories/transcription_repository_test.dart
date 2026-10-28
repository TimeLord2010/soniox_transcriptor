import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
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

    test('aceita final vazio', () {
      repo.insert(recordAt(1, text: ''));

      expect(repo.getAll().single.finalText, '');
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

  group('limite de registros', () {
    test('guarda no máximo 100, descartando os mais antigos', () {
      for (var i = 1; i <= 101; i++) {
        repo.insert(recordAt(i, text: 'r$i'));
      }

      final all = repo.getAll();
      expect(all, hasLength(100));
      expect(all.any((r) => r.finalText == 'r1'), isFalse);
      expect(all.first.finalText, 'r101');
    });

    test('não descarta nada enquanto está abaixo do limite', () {
      for (var i = 1; i <= 99; i++) {
        repo.insert(recordAt(i));
      }

      expect(repo.getAll(), hasLength(99));
    });
  });
}
