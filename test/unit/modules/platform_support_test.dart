import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride, kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';

/// `PlatformSupport` é quem impede o app de usar `dart:io` — e no web
/// `Platform.*` lança em runtime. Este arquivo roda no host E em Chrome
/// (`flutter test --platform chrome test/unit/modules/platform_support_test.dart`),
/// que é a única forma de exercitar o ramo web de verdade.
void main() {
  tearDown(() {
    PlatformSupport.debugForceSupportsGlobalHotkey(null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('plataforma macOS: atalho global e "Clique", mas nunca no web', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    // No Chrome de um Mac o `defaultTargetPlatform` também é macOS — o que
    // segura isso é o `!kIsWeb` dentro do PlatformSupport.
    expect(PlatformSupport.isMacOS, !kIsWeb);
    expect(PlatformSupport.supportsGlobalHotkey, !kIsWeb);
    expect(PlatformSupport.canPasteIntoOtherApp, !kIsWeb);
    expect(PlatformSupport.usesClickVerb, isTrue);
    expect(PlatformSupport.name, kIsWeb ? 'web' : 'macOS');
  });

  test('plataforma Android: sem atalho, rótulo "Toque"', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(PlatformSupport.isAndroid, !kIsWeb);
    expect(PlatformSupport.isMacOS, isFalse);
    expect(PlatformSupport.supportsGlobalHotkey, isFalse);
    // No web o rótulo continua "Clique": o alvo é o navegador, não o dedo.
    expect(PlatformSupport.usesClickVerb, kIsWeb);
    expect(PlatformSupport.name, kIsWeb ? 'web' : 'Android');
  });

  test('forçar a capacidade sobrepõe a plataforma (macOS sem atalho)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    PlatformSupport.debugForceSupportsGlobalHotkey(false);

    expect(PlatformSupport.supportsGlobalHotkey, isFalse);
    expect(PlatformSupport.canPasteIntoOtherApp, isFalse);
    expect(PlatformSupport.usesClickVerb, isFalse);
  });

  test('mensagem de microfone negado aponta o caminho de cada sistema', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final macMessage = PlatformSupport.micPermissionDeniedMessage;
    expect(macMessage, startsWith('Permissão de microfone negada.'));

    if (kIsWeb) {
      expect(PlatformSupport.isWeb, isTrue);
      expect(macMessage, contains('barra de endereços'));
      return;
    }

    // Não é web: com override de macOS o texto é o do macOS, e com Android é o
    // do app — o texto do navegador não pode aparecer em nenhum dos dois.
    expect(PlatformSupport.isWeb, isFalse);
    expect(macMessage, contains('Ajustes do Sistema'));

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final androidMessage = PlatformSupport.micPermissionDeniedMessage;
    expect(androidMessage, contains('Configurações > Apps'));
    expect(androidMessage, isNot(contains('barra de endereços')));
  });
}
