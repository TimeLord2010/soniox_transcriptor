import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;

/// O que o sistema atual consegue fazer.
///
/// O app nasceu como utilitário de macOS: a sessão inteira pendura numa tecla
/// global, o andamento aparece num painel flutuante nativo e o texto final é
/// colado no app em foco por um Cmd+V sintetizado. Nada disso existe fora do
/// macOS — em especial no Android e no navegador —, então cada capacidade é
/// decidida aqui em vez de espalhar checagem de sistema pelo código.
///
/// Não usa `dart:io`: no web esse import compila, mas qualquer acesso a
/// `Platform.*` lança `Unsupported operation: Platform._operatingSystem` em
/// runtime (verificado em Chrome). `defaultTargetPlatform` também não basta
/// sozinho: no navegador ele segue o sistema do usuário — um Mac aberto no
/// Chrome reporta `macOS` —, então todo teste de SO começa com `!kIsWeb`.
class PlatformSupport {
  PlatformSupport._();

  static bool? _forcedGlobalHotkey;

  /// Rodando no navegador. Fonte única: nada de `kIsWeb` espalhado.
  static bool get isWeb => kIsWeb;

  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Monitor de tecla global + painel flutuante + colagem sintética: os três
  /// moram no plugin nativo `macos/Runner/HotkeyPlugin.swift`.
  static bool get supportsGlobalHotkey => _forcedGlobalHotkey ?? isMacOS;

  /// Se dá para digitar o resultado dentro de OUTRO app. Exige sintetizar um
  /// Cmd+V, então só onde existe o plugin do macOS; no Android e no web o texto
  /// fica na sandbox e na área de transferência.
  static bool get canPasteIntoOtherApp => supportsGlobalHotkey;

  /// Rótulo do comando de captura: "Clique" com mouse, "Toque" com o dedo. O
  /// web conta como clique — o alvo é o navegador, mesmo aberto num tablet.
  /// O forçado dos testes vale aqui também para exercitar os dois textos.
  static bool get usesClickVerb => _forcedGlobalHotkey ?? (isWeb || isMacOS);

  /// Nome da plataforma para textos de interface.
  static String get name {
    if (isWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// Permissão de microfone negada, com o caminho de autorização de cada
  /// sistema: a tela de permissões do macOS não existe no Android, e no
  /// navegador a permissão é do site, não do app.
  static String get micPermissionDeniedMessage {
    if (isWeb) {
      return 'Permissão de microfone negada. Libere o microfone para este site '
          'no ícone da barra de endereços do navegador e tente de novo.';
    }
    if (isMacOS) {
      return 'Permissão de microfone negada. Autorize o soniox_transcriptor em '
          'Ajustes do Sistema > Privacidade e Segurança > Microfone.';
    }
    if (isAndroid) {
      return 'Permissão de microfone negada. Autorize o microfone para o app em '
          'Configurações > Apps > soniox_transcriptor > Permissões.';
    }
    return 'Permissão de microfone negada. Autorize o microfone nas '
        'configurações de privacidade do sistema.';
  }

  /// Os testes rodam no host (macOS) e ficam no caminho do atalho global por
  /// padrão; isto fixa a capacidade para exercitar o caminho do Android.
  @visibleForTesting
  static void debugForceSupportsGlobalHotkey(bool? value) =>
      _forcedGlobalHotkey = value;
}
