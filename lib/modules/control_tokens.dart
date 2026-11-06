/// Marcadores de controle do protocolo Soniox — nunca são texto transcrito.
///
/// `<end>` marca fim de fala (endpoint) e `<fin>` fecha o `finalize`, que é o
/// que o servidor devolve quando a captura é PARADA. Os dois chegam como
/// token comum na lista, então quem monta o texto precisa descartá-los: sem
/// isso o `<fin>` é digitado no campo do app em foco (no teclado Android ele
/// aparecia ao tocar em "parar") e sobra na sandbox/histórico.
final RegExp _controlToken = RegExp(r'<(?:end|fin)>');

/// O token inteiro é um marcador (e não uma palavra com marcador colado).
bool isControlToken(String text) =>
    _controlToken.hasMatch(text) && withoutControlTokens(text).isEmpty;

/// Texto sem os marcadores — para quem recebe texto já concatenado (SDK).
String withoutControlTokens(String text) => text.replaceAll(_controlToken, '');
