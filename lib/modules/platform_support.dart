import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// O que o sistema atual consegue fazer.
///
/// O app nasceu como utilitário de macOS: a sessão inteira pendura numa tecla
/// global, o andamento aparece num painel flutuante nativo e o texto final é
/// colado no app em foco por um Cmd+V sintetizado. Nada disso existe fora do
/// macOS — em especial no Android —, então cada capacidade é decidida aqui em
/// vez de espalhar `Platform.isMacOS` pelo código.
class PlatformSupport {
  PlatformSupport._();

  static bool? _forcedGlobalHotkey;

  /// Monitor de tecla global + painel flutuante + colagem sintética: os três
  /// moram no plugin nativo `macos/Runner/HotkeyPlugin.swift`.
  static bool get supportsGlobalHotkey =>
      _forcedGlobalHotkey ?? Platform.isMacOS;

  /// Se dá para digitar o resultado dentro de OUTRO app. Exige sintetizar um
  /// Cmd+V, então só onde existe o plugin do macOS; no Android o texto fica na
  /// sandbox e na área de transferência.
  static bool get canPasteIntoOtherApp => supportsGlobalHotkey;

  /// Nome da plataforma para textos de interface.
  static String get name {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    return Platform.operatingSystem;
  }

  /// Os testes rodam no host (macOS) e ficam no caminho do atalho global por
  /// padrão; isto fixa a capacidade para exercitar o caminho do Android.
  @visibleForTesting
  static void debugForceSupportsGlobalHotkey(bool? value) =>
      _forcedGlobalHotkey = value;
}
