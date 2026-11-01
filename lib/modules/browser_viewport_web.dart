import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// Barra do navegador = o que o layout viewport tem a mais que o viewport
/// visível. `documentElement.clientHeight` é exatamente o valor que o engine
/// usa para dimensionar a tela (no iOS ele nem consulta o `visualViewport`).
double browserBottomInset() {
  final visible = web.window.visualViewport?.height ?? web.window.innerHeight;
  final layout = web.document.documentElement?.clientHeight.toDouble();
  if (layout == null) return 0;
  return math.max(0, layout - visible);
}
