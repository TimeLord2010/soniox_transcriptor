import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/components/transcriptions_history.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('sem registros mostra o estado vazio', (tester) async {
    await setUpAppEnvironment();
    await pumpCupertinoWidget(tester, const TranscriptionsHistory());

    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Sem transcrições'), findsOneWidget);
  });

  testWidgets('lista as transcrições salvas, mais recentes primeiro', (
    tester,
  ) async {
    await setUpAppEnvironment();
    final repo = GetIt.I.get<TranscriptionRepository>();
    repo.insert(
      TranscriptionRecord(
        finalText: 'primeira gravação',
        nonFinalText: '',
        createdAt: DateTime(2026, 10, 1, 9),
      ),
    );
    repo.insert(
      TranscriptionRecord(
        finalText: 'segunda gravação',
        nonFinalText: '',
        createdAt: DateTime(2026, 10, 2, 9),
      ),
    );

    await pumpCupertinoWidget(tester, const TranscriptionsHistory());
    await tester.pumpAndSettle();

    expect(find.text('primeira gravação'), findsOneWidget);
    expect(find.text('segunda gravação'), findsOneWidget);
    expect(find.text('Sem transcrições'), findsNothing);

    final firstItemY = tester.getTopLeft(find.text('segunda gravação')).dy;
    final secondItemY = tester.getTopLeft(find.text('primeira gravação')).dy;
    expect(firstItemY, lessThan(secondItemY));
  });

  testWidgets('limpar histórico pede confirmação e esvazia a lista', (
    tester,
  ) async {
    await setUpAppEnvironment();
    final repo = GetIt.I.get<TranscriptionRepository>();
    repo.insert(
      TranscriptionRecord(
        finalText: 'vai sumir',
        nonFinalText: '',
        createdAt: DateTime(2026, 10, 3, 9),
      ),
    );

    await pumpCupertinoWidget(tester, const TranscriptionsHistory());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.trash));
    await tester.pumpAndSettle();
    expect(find.text('Clear all history?'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('vai sumir'), findsNothing);
    expect(find.text('Sem transcrições'), findsOneWidget);
    expect(repo.getAll(), isEmpty);
  });
}
