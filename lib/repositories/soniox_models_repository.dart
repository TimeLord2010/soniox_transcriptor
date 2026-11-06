import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soniox_transcriptor/models/soniox_model.dart';

/// Falha ao listar os modelos: sem rede, chave inválida ou resposta inesperada.
/// A lista em cache continua valendo, então o app não fica sem modelo.
class SonioxModelsException implements Exception {
  SonioxModelsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lista os modelos disponíveis na conta (`GET /v1/models`) e guarda a última
/// resposta boa no disco.
///
/// O cache existe porque a sessão pode ser reconstruída antes da rede
/// responder (abrir o app, trocar de perfil): sem ele o modelo automático
/// cairia no fallback do código mesmo com a lista já conhecida.
class SonioxModelsRepository {
  static const endpoint = 'https://api.soniox.com/v1/models';
  static const _cacheKey = 'soniox.models.cache';
  static const _timeout = Duration(seconds: 10);

  /// Cliente HTTP injetável: teste troca por um fake sem tocar na rede.
  SonioxModelsRepository({http.Client? client}) : _client = client;

  final http.Client? _client;

  SharedPreferences get _sp => GetIt.I.get<SharedPreferences>();

  /// Modelos de tempo real, do mais novo para o mais antigo. Lança
  /// [SonioxModelsException] com mensagem pronta para a UI.
  Future<List<SonioxModel>> fetch(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      throw SonioxModelsException('Informe a chave do Soniox para listar.');
    }
    http.Response response;
    try {
      final request = (_client ?? http.Client()).get(
        Uri.parse(endpoint),
        headers: {'Authorization': 'Bearer ${apiKey.trim()}'},
      );
      response = await request.timeout(_timeout);
    } catch (error) {
      throw SonioxModelsException('Falha ao consultar o Soniox: $error');
    }
    if (response.statusCode != 200) {
      throw SonioxModelsException(
        'O Soniox respondeu ${response.statusCode} ao listar os modelos.',
      );
    }
    final List<SonioxModel> models;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = (body['models'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      models = SonioxModel.realTimeOnly(raw.map(SonioxModel.fromJson).toList());
    } catch (error) {
      throw SonioxModelsException('Resposta inesperada do Soniox: $error');
    }
    if (models.isEmpty) {
      throw SonioxModelsException('O Soniox não devolveu nenhum modelo.');
    }
    await _cache(models);
    return models;
  }

  /// Última lista boa, sem rede. Vazia se o app nunca conseguiu listar.
  List<SonioxModel> cached() {
    final stored = _sp.getString(_cacheKey);
    if (stored == null) return const [];
    try {
      final raw = (jsonDecode(stored) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      return SonioxModel.realTimeOnly(raw.map(SonioxModel.fromJson).toList());
    } catch (_) {
      return const [];
    }
  }

  Future<void> _cache(List<SonioxModel> models) async {
    final payload = [
      for (final model in models)
        {
          'id': model.id,
          'name': model.name,
          'transcription_mode': model.mode,
          'aliased_model_id': model.aliasTarget,
        },
    ];
    await _sp.setString(_cacheKey, jsonEncode(payload));
  }
}
