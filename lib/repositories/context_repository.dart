import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContextRepository {
  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  String getContext() {
    return _sp.getString('context_text') ?? '';
  }

  Future<void> setContext(String text) async {
    await _sp.setString('context_text', text);
  }
}
