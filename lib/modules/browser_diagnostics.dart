import 'package:flutter/widgets.dart';

import 'browser_diagnostics_stub.dart'
    if (dart.library.js_interop) 'browser_diagnostics_web.dart'
    as impl;

/// Uma linha de texto por medida de viewport, para pôr na tela quando o layout
/// no celular não bate com o que o Dart acha que tem de espaço.
///
/// Serve para diagnosticar sem adivinhar: mostra o que o navegador reporta, o
/// que o engine está desenhando e o recuo que o app aplicou. Fora do navegador
/// devolve texto vazio (não desenha nada).
String browserDiagnostics({
  required double surfaceHeight,
  required EdgeInsets insets,
}) => impl.browserDiagnostics(surfaceHeight: surfaceHeight, insets: insets);
