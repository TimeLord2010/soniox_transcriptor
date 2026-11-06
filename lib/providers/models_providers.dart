import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soniox_transcriptor/models/soniox_model.dart';
import 'package:soniox_transcriptor/providers/api_key_provider.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/model_repository.dart';
import 'package:soniox_transcriptor/repositories/soniox_models_repository.dart';

/// Situação da lista de modelos do Soniox.
class ModelsState {
  const ModelsState({
    this.isLoading = false,
    this.models = const [],
    this.error,
  });

  /// Modelos de tempo real, mais novos primeiro.
  final List<SonioxModel> models;
  final bool isLoading;

  /// Última falha ao listar, com mensagem pronta para a UI. A lista anterior
  /// (cache) continua em [models].
  final String? error;

  ModelsState copyWith({
    bool? isLoading,
    List<SonioxModel>? models,
    String? error,
    bool clearError = false,
  }) {
    return ModelsState(
      isLoading: isLoading ?? this.isLoading,
      models: models ?? this.models,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Lista de modelos publicados pelo Soniox para a chave do perfil ativo.
///
/// Busca na abertura do app (a sessão precisa saber qual modelo usar antes de
/// qualquer clique) e de novo quando a chave muda. Falha nunca deixa a UI sem
/// opção: a última lista boa fica em cache e, sem nenhuma, vale o fallback.
final sonioxModelsProvider =
    StateNotifierProvider<SonioxModelsNotifier, ModelsState>((ref) {
      return SonioxModelsNotifier(
        repository: SonioxModelsRepository(),
        apiKey: ref.watch(apiKeyProvider),
      );
    });

/// Modelo escolhido no perfil ativo; `null` = automático (mais novo).
final selectedModelProvider =
    StateNotifierProvider<SelectedModelNotifier, String?>(
      (ref) => SelectedModelNotifier(ref.watch(activeProfileIdProvider)),
    );

/// Id que vai no config da sessão: o escolhido, ou o mais novo que a API
/// publicou, ou o fallback do código se a lista nunca chegou.
final resolvedModelIdProvider = Provider<String>((ref) {
  final selected = ref.watch(selectedModelProvider);
  if (selected != null) return selected;
  final models = ref.watch(sonioxModelsProvider).models;
  return models.isEmpty ? SonioxModel.fallbackId : models.first.id;
});

class SonioxModelsNotifier extends StateNotifier<ModelsState> {
  SonioxModelsNotifier({
    required SonioxModelsRepository repository,
    required String apiKey,
  }) : _repository = repository,
       _apiKey = apiKey,
       super(
         ModelsState(
           models: repository.cached(),
           isLoading: apiKey.trim().isNotEmpty,
         ),
       ) {
    if (apiKey.trim().isNotEmpty) refresh();
  }

  final SonioxModelsRepository _repository;
  final String _apiKey;

  Future<void> refresh() async {
    if (_apiKey.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Informe a chave do Soniox para listar os modelos.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final models = await _repository.fetch(_apiKey);
      if (!mounted) return;
      state = ModelsState(models: models);
    } on SonioxModelsException catch (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: error.message);
    }
  }
}

class SelectedModelNotifier extends StateNotifier<String?> {
  SelectedModelNotifier(String profileId)
    : _repository = ModelRepository(profileId),
      super(ModelRepository(profileId).getModel());

  final ModelRepository _repository;

  /// `null` volta para o automático (mais novo publicado pelo Soniox).
  Future<void> select(String? id) async {
    await _repository.setModel(id);
    state = id;
  }
}
