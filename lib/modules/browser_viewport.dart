import 'browser_viewport_stub.dart'
    if (dart.library.js_interop) 'browser_viewport_web.dart'
    as impl;

/// Altura, em pixels lógicos, da faixa do app que a barra do navegador cobre.
///
/// No navegador o `MediaQuery.padding` é zero (barra do navegador não é inset
/// do sistema), e no iOS o engine dimensiona a tela por
/// `documentElement.clientHeight` — que é o layout viewport, MAIOR que a área
/// visível: o rodapé (a tab bar) ficava atrás da barra do Safari. Quem sabe a
/// diferença é o `visualViewport`, então o inset vem de lá.
///
/// Zero fora do navegador.
double browserBottomInset() => impl.browserBottomInset();
