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
    expect(container.read(historyProvider), isEmpty);
  });

  test(
    'carrega o banco na primeira leitura, do mais novo para o mais antigo',
    () {
      repo.insert(recordAt(1, 'antiga'));
      repo.insert(recordAt(2, 'nova'));

      expect(container.read(historyProvider).map((r) => r.finalText), [
        'nova',
        'antiga',
      ]);
    },
  );

  test('não relê o banco sozinho: precisa de invalidate', () {
    expect(container.read(historyProvider), isEmpty);
    repo.insert(recordAt(1, 'gravada depois'));
    expect(container.read(historyProvider), isEmpty);

    container.invalidate(historyProvider);

    expect(container.read(historyProvider).single.finalText, 'gravada depois');
  });

  test('limpar o histórico zera o estado depois do deleteAll', () {
    repo.insert(recordAt(1, 'antiga'));
    expect(container.read(historyProvider), hasLength(1));

    repo.deleteAll();
    container.read(historyProvider.notifier).state = repo.getAll();

    expect(container.read(historyProvider), isEmpty);
  });
}
