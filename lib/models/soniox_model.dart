/// Um modelo de transcrição oferecido pelo Soniox (`GET /v1/models`).
///
/// O app não decide mais no código qual modelo usar: a lista vem da API e a
/// escolha fica salva no perfil. [id] é o que vai no campo `model` do config da
/// sessão; [name] é o rótulo legível que o Soniox publica.
class SonioxModel {
  const SonioxModel({
    required this.id,
    required this.name,
    required this.mode,
    required this.aliasTarget,
  });

  /// Modelo usado quando a lista não pôde ser lida (sem chave, sem rede) e o
  /// perfil ainda não escolheu nada. Único ponto do código que fala de versão.
  static const fallbackId = 'stt-rt-v5';

  /// Modo de transcrição que este app consome: o app é tempo real.
  static const realTimeMode = 'real_time';

  final String id;
  final String name;

  /// `real_time` / `async` no vocabulário do Soniox.
  final String mode;

  /// Modelo para o qual este foi apelidado (preview/legado). `null` = modelo
  /// de verdade, o que a lista coloca na frente.
  final String? aliasTarget;

  bool get isAlias => aliasTarget != null;

  bool get isRealTime => mode == realTimeMode;

  /// Versão numérica do id (`stt-rt-v6` → 6), base da ordenação.
  int get version {
    final match = RegExp(r'v(\d+)').firstMatch(id);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  factory SonioxModel.fromJson(Map<String, dynamic> map) {
    final alias = map['aliased_model_id'];
    final name = map['name'];
    return SonioxModel(
      id: map['id'] as String,
      name: name is String && name.trim().isNotEmpty
          ? name
          : map['id'] as String,
      mode: (map['transcription_mode'] as String?) ?? '',
      aliasTarget: alias is String && alias.isNotEmpty ? alias : null,
    );
  }

  /// Só os modelos de tempo real (o app não faz transcrição assíncrona), na
  /// ordem em que a UI deve mostrá-los: estáveis antes dos apelidos
  /// (preview/legado), mais novos primeiro.
  static List<SonioxModel> realTimeOnly(List<SonioxModel> models) {
    final realTime = models.where((model) => model.isRealTime).toList();
    realTime.sort((a, b) {
      if (a.isAlias != b.isAlias) return a.isAlias ? 1 : -1;
      if (a.version != b.version) return b.version.compareTo(a.version);
      return a.id.compareTo(b.id);
    });
    return realTime;
  }
}
