import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// O que o layout viewport tem a mais que a área visível, nos três lados em que
/// isso acontece: embaixo (barra do Safari), à direita (largura do layout maior
/// que a visível) e à esquerda (quando o usuário rolou na horizontal).
///
/// `documentElement.client*` é exatamente o que o engine usa para dimensionar a
/// tela — no iOS ele nem consulta o `visualViewport` fora de edição de texto.
EdgeInsets browserInsets() {
  final viewport = web.window.visualViewport;
  final root = web.document.documentElement;
  if (viewport == null || root == null) return EdgeInsets.zero;

  // Pinch-zoom: o layout fica maior por ESCALA, não por barra do navegador.
  // Descontar aqui encolheria o conteúdo sem alinhar nada.
  if ((viewport.scale - 1).abs() > 0.01) return EdgeInsets.zero;

  final layoutWidth = root.clientWidth.toDouble();
  final layoutHeight = root.clientHeight.toDouble();
  final left = math.max(0.0, viewport.offsetLeft);
  final right = math.max(
    0.0,
    layoutWidth - viewport.width - viewport.offsetLeft,
  );
  final bottom = math.max(
    0.0,
    layoutHeight - viewport.height - viewport.offsetTop,
  );
  return EdgeInsets.only(left: left, right: right, bottom: bottom);
}
