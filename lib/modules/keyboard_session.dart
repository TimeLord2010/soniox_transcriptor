import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/models/languages.dart';

/// O que o teclado Android (nativo, Kotlin) precisa para abrir uma sessão.
///
/// O teclado é um `InputMethodService`: não tem motor do Flutter nem acesso aos
/// providers. Em vez de ele ler as chaves internas de perfil — formato que muda
/// quando o app muda —, o app publica UM blob versionado nas preferências
/// compartilhadas, e o teclado lê só ele (contrato em
/// `android/app/src/main/kotlin/com/vit/soniox/keyboard/KeyboardSession.kt`).
///
/// Publicar é barato (uma escrita de string) e acontece a cada mudança de
/// perfil/configuração: o teclado sempre abre com o perfil ativo atual.
class KeyboardSession {
  KeyboardSession._();

  /// Chave nas preferências do app. O plugin prefixa com `flutter.` no Android,
  /// então o teclado procura `flutter.keyboard.session`.
  static const storageKey = 'keyboard.session';

  /// `2` — acrescentou `model`. O teclado recusa blob de versão que não
  /// conhece (campo novo sem quebra silenciosa do lado dele) e aceita a `1`
  /// ainda, preenchendo o modelo padrão.
  static const version = 2;

  static Map<String, dynamic> toMap({
    required String apiKey,
    required String model,
    required Set<Language> languages,
    required String contextText,
    required List<String> terms,
    required Language? translationTarget,
  }) {
    return {
      'version': version,
      'api_key': apiKey,
      // Modelo escolhido no perfil (ou o automático resolvido pelo app).
      'model': model,
      'languages': languages.map((language) => language.name).toList(),
      'context_text': contextText,
      'terms': terms,
      // `null` = tradução desligada: sem alvo não existe sessão traduzida.
      'translation_target': translationTarget?.name,
    };
  }

  /// Grava o blob do perfil ativo. Falha não interrompe o app (o teclado vai
  /// mostrar "sem chave"), mas fica no log.
  static Future<void> publish({
    required String apiKey,
    required String model,
    required Set<Language> languages,
    required String contextText,
    required List<String> terms,
    required Language? translationTarget,
  }) async {
    if (!GetIt.I.isRegistered<SharedPreferences>()) return;
    final prefs = GetIt.I.get<SharedPreferences>();
    final payload = jsonEncode(
      toMap(
        apiKey: apiKey,
        model: model,
        languages: languages,
        contextText: contextText,
        terms: terms,
        translationTarget: translationTarget,
      ),
    );
    try {
      await prefs.setString(storageKey, payload);
    } catch (e) {
      debugPrint('[KeyboardSession] publicar falhou: $e');
    }
  }
}
