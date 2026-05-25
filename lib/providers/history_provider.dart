import 'package:get_it/get_it.dart';
import 'package:riverpod/riverpod.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';

import '../repositories/transcription_repository.dart';

final historyProvider = StateProvider<List<TranscriptionRecord>>((_) {
  return GetIt.I.get<TranscriptionRepository>().getAll();
});
