import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:soniox_transcriptor/models/usage_cost.dart';

/// Falha ao consultar o log de uso: sem rede, chave inválida ou resposta
/// inesperada. Quem chama tenta de novo mais tarde.
class UsageLogsException implements Exception {
  UsageLogsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lê o custo exato das sessões em `GET /v1/usage-logs` (o Soniox registra cada
/// sessão concluída com o `client_reference_id` enviado no `start`).
class UsageLogsRepository {
  static const endpoint = 'https://api.soniox.com/v1/usage-logs';

  /// A API aceita no máximo 31 dias por consulta e histórico de 91 dias.
  static const maxWindow = Duration(days: 30);
  static const maxHistory = Duration(days: 90);
  static const _timeout = Duration(seconds: 15);

  UsageLogsRepository({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Custo por `client_reference_id` das sessões encerradas em [from]..[to]
  /// (a API filtra pelo fim da sessão). Divide em janelas de 30 dias e segue a
  /// paginação. Lança [UsageLogsException] em qualquer falha.
  Future<Map<String, UsageCost>> fetch(
    String apiKey, {
    required DateTime from,
    required DateTime to,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) throw UsageLogsException('Chave do Soniox vazia.');
    final earliest = DateTime.now().toUtc().subtract(maxHistory);
    var start = from.toUtc().isBefore(earliest) ? earliest : from.toUtc();
    final end = to.toUtc();
    final result = <String, UsageCost>{};
    while (start.isBefore(end)) {
      final windowEnd = start.add(maxWindow).isBefore(end)
          ? start.add(maxWindow)
          : end;
      String? cursor;
      do {
        final body = await _get(key, start, windowEnd, cursor);
        for (final entry in UsageCost.byReference(body).entries) {
          final previous = result[entry.key];
          result[entry.key] = previous == null
              ? entry.value
              : previous.plus(entry.value);
        }
        cursor = body is Map ? body['next_page_cursor'] as String? : null;
      } while (cursor != null);
      start = windowEnd;
    }
    return result;
  }

  Future<Object?> _get(
    String key,
    DateTime start,
    DateTime end,
    String? cursor,
  ) async {
    String iso(DateTime d) => '${d.toIso8601String().split('.').first}Z';
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'start_time': iso(start),
        'end_time': iso(end),
        'limit': '1000',
        'cursor': ?cursor,
      },
    );
    final http.Response response;
    try {
      response = await (_client ?? http.Client())
          .get(uri, headers: {'Authorization': 'Bearer $key'})
          .timeout(_timeout);
    } catch (error) {
      throw UsageLogsException('Falha ao consultar o log de uso: $error');
    }
    if (response.statusCode != 200) {
      throw UsageLogsException(
        'O Soniox respondeu ${response.statusCode} ao consultar o log de uso.',
      );
    }
    try {
      return jsonDecode(response.body);
    } catch (error) {
      throw UsageLogsException('Resposta do log de uso ilegível: $error');
    }
  }
}
