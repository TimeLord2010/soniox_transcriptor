import 'package:vit_soniox/vit_soniox.dart';

/// Mensagem para o usuário a partir do erro que o pacote entrega.
///
/// O `vit_soniox` reporta falha de conexão com código 0, e 401 é chave
/// recusada — os dois casos tem texto próprio em vez do genérico.
String describeSonioxError(SonioxError error) {
  return switch (error.code) {
    401 => 'Chave Soniox inválida. Verifique a chave do perfil.',
    0 => 'Não foi possível conectar à Soniox: ${error.message}',
    _ => 'Erro Soniox (${error.code}): ${error.message}',
  };
}
