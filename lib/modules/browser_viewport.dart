import 'package:flutter/widgets.dart';

import 'browser_viewport_stub.dart'
    if (dart.library.js_interop) 'browser_viewport_web.dart'
    as impl;

/// Recuo, em pixels lógicos, entre o layout viewport e a área que o usuário
/// realmente vê no navegador.
///
/// No web o `MediaQuery.padding` é zero (a barra do navegador não é inset do
/// sistema) e no iOS o engine dimensiona a tela por `documentElement.client*`
/// — o layout viewport, MAIOR que a área visível. Daí a tab bar ficar atrás da
/// barra do Safari e o conteúdo ser cortado à direita. Quem sabe a diferença é
/// o `visualViewport`, então o recuo vem de lá.
///
/// Fora do navegador é [EdgeInsets.zero].
///
/// [surfaceHeight] é a altura que o Flutter desenha (o tamanho da view). Passar
/// isso evita contar o teclado duas vezes quando o engine já encolheu a view
/// para o `visualViewport`.
EdgeInsets browserInsets({double? surfaceHeight}) =>
    impl.browserInsets(surfaceHeight: surfaceHeight);
