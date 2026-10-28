import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zera o GetIt e registra um SharedPreferences em memória (store real de teste
/// oficial do plugin) pronto para os módulos do app.
Future<SharedPreferences> setUpPrefs([
  Map<String, Object> seed = const {},
]) async {
  await GetIt.I.reset();
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  GetIt.I.registerSingleton<SharedPreferences>(prefs);
  return prefs;
}

/// O SharedPreferences que [setUpPrefs] deixou registrado no GetIt.
SharedPreferences get currentPrefs => GetIt.I.get<SharedPreferences>();

/// Remove tudo do GetIt depois do teste.
Future<void> tearDownGetIt() => GetIt.I.reset();
