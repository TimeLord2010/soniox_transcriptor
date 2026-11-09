import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

String _n(num? v) => v == null ? '?' : v.toStringAsFixed(1);

/// Medidas cruas do viewport do navegador + o que o app decidiu fazer com elas.
///
/// `client` é o layout viewport que o engine usa para dimensionar a tela;
/// `vv` é o `visualViewport` (área realmente visível, que encolhe com o teclado);
/// `surface` é a altura da caixa que o Flutter está desenhando (constraint) e
/// `media` é o que o `MediaQuery` do tree diz — no Safari do iPhone os dois
/// divergem com o teclado aberto (constraint 396, MediaQuery 699), e medir pelo
/// MediaQuery espremia a Sandbox.
String browserDiagnostics({
  required double surfaceHeight,
  required double mediaHeight,
  required EdgeInsets insets,
}) {
  final root = web.document.documentElement;
  final vv = web.window.visualViewport;
  final win = web.window;
  final viewport = vv == null
      ? 'vv ausente'
      : 'vv ${_n(vv.width)}x${_n(vv.height)}'
            '  off ${_n(vv.offsetLeft)}/${_n(vv.offsetTop)}'
            '  scale ${_n(vv.scale)}';
  final lines = <String>[
    'client ${_n(root?.clientWidth.toDouble())}'
        'x${_n(root?.clientHeight.toDouble())}'
        '  inner ${_n(win.innerWidth.toDouble())}'
        'x${_n(win.innerHeight.toDouble())}'
        '  dpr ${_n(win.devicePixelRatio)}',
    viewport,
    'surface ${_n(surfaceHeight)}  media ${_n(mediaHeight)}'
        '  inset l${insets.left.toStringAsFixed(0)}'
        ' r${insets.right.toStringAsFixed(0)}'
        ' b${insets.bottom.toStringAsFixed(0)}',
  ];
  return lines.join('\n');
}
