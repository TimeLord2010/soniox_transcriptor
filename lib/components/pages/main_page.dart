import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/components/api_key_setter.dart';
import 'package:soniox_transcriptor/components/context_text_setter.dart';
import 'package:soniox_transcriptor/components/device_picker.dart';
import 'package:soniox_transcriptor/components/language_picker.dart';
import 'package:soniox_transcriptor/components/profile_selector.dart';
import 'package:soniox_transcriptor/components/record_button.dart';
import 'package:soniox_transcriptor/components/sandbox_settings.dart';
import 'package:soniox_transcriptor/components/styles/ui.dart';
import 'package:soniox_transcriptor/components/terms_picker.dart';
import 'package:soniox_transcriptor/components/transcriptions_history.dart';
import 'package:soniox_transcriptor/components/translation_settings.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/modules/diarized_text.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';
import 'package:soniox_transcriptor/modules/session_config.dart';
import 'package:soniox_transcriptor/modules/translated_event.dart';
import 'package:soniox_transcriptor/protocols/show_toast.dart';
import 'package:soniox_transcriptor/providers/api_key_provider.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';
import 'package:soniox_transcriptor/providers/history_provider.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/hotkey_listener.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:soniox_transcriptor/repositories/soniox_websocket_impl.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';
import 'package:vit_soniox/vit_soniox.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  late final hotkeyListener = HotkeyListener(
    onKeyDown: () {},
    onKeyUp: () {},
    onInsertText: _insertIntoSandbox,
  );

  /// Captura de áudio. Sai do GetIt quando o teste registra um gravador falso;
  /// no app normal é o do microfone.
  late final recorder = GetIt.I.isRegistered<RecorderRepository>()
      ? GetIt.I.get<RecorderRepository>()
      : RecorderRepository();
  final _sandboxController = TextEditingController();
  final _sandboxFocusNode = FocusNode();

  /// Texto traduzido da sessão atual. Vive fora da sandbox de propósito: os
  /// dois textos têm destinos diferentes (a sandbox é o que foi falado).
  final _translationController = TextEditingController();
  SonioxWebsocket? soniox;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<List<int>>? _recordStreamSubscription;
  StreamSubscription? _transcriptionSubscription;
  StreamSubscription<SonioxError>? _errorSubscription;
  StreamSubscription<String>? _recorderErrorSubscription;
  bool _isProcessing = false;

  /// Comando de captura pelo toque/clique, presente nas duas plataformas: no
  /// Android é o único jeito de abrir uma sessão; no macOS convive com a tecla
  /// global e entrega o texto na sandbox.
  bool _recording = false;

  /// Índices das abas da barra inferior.
  static const int _homeTab = 0;
  static const int _sandboxTab = 1;

  /// A sessão foi aberta pelo botão de gravar em vez da tecla global. Nesse
  /// caso o destino é a sandbox em qualquer plataforma — inclusive no macOS,
  /// onde a tecla global cola no app em foco (que seria o próprio app).
  bool _sessionFromButton = false;

  // Session state. Lives in fields (not in the session-setup closures) so both
  // transports — the macOS hotkey and the on-screen button — drive the same
  // capture.
  final _buffer = StringBuffer();
  String _nonFinal = '';
  String? _sessionError;

  /// Sandbox content at the moment the capture started; the live text is
  /// appended to it instead of overwriting what the user had typed.
  String _sandboxBaseText = '';

  /// Preenchido só na sessão com diarização ligada: monta o texto final com o
  /// rótulo do falante. Criado por sessão para zerar o falante corrente.
  DiarizedTextBuilder? _diarized;

  /// Língua alvo da tradução congelada no início da sessão (`null` = tradução
  /// desligada). Como a diarização, é parâmetro de conexão: mudar a opção no
  /// meio da captura só vale na próxima.
  Language? _translationTarget;

  /// Tradução acumulada da sessão; o texto ao vivo é este buffer mais a prévia
  /// não final.
  final _translationBuffer = StringBuffer();
  String _nonFinalTranslation = '';

  /// Controle de log/aviso do caminho da tradução (uma vez por sessão).
  bool _translationLogged = false;
  bool _translationErrorReported = false;

  /// A sessão recebeu fala que o Soniox não traduziu (`translation_status` =
  /// "none"): a fala já está na língua alvo. Sem essa explicação o campo da
  /// tradução fica vazio e parece defeito.
  bool _untranslatedSpeech = false;
  bool _showNothingToTranslate = false;

  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (PlatformSupport.supportsGlobalHotkey) {
      hotkeyListener.start().catchError((Object e) {
        debugPrint('[MainPage] hotkeyListener.start() error: $e');
      });
    }
    _updateSonioxInstance();
  }

  @override
  void dispose() {
    // The native hotkey monitor is a single, app-global resource. MainPage can
    // mount more than once (a theme/shell rebuild replaces the subtree), and
    // calling the static stop() here would tear down the monitor that a newer,
    // still-alive MainPage just registered. Let it live for the app's
    // lifetime; the OS reclaims it on exit.
    _sandboxController.dispose();
    _sandboxFocusNode.dispose();
    _translationController.dispose();
    _recorderErrorSubscription?.cancel();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The session depends on the active profile (key, terms, languages and
    // context), so rebuild it when either the key or the profile changes.
    // Both can fire in the same frame on a switch; coalesce into one rebuild.
    ref.listen(apiKeyProvider, (_, _) => _scheduleSessionRebuild());
    ref.listen(activeProfileIdProvider, (_, _) => _scheduleSessionRebuild());
    // A diarização é parâmetro de sessão: mudar a caixa de marcar reconstrói a
    // conexão com o Soniox (só vale na próxima captura, como a chave/termos).
    ref.listen(diarizationProvider, (_, _) {
      _scheduleSessionRebuild();
      _notifyPendingSetting();
    });
    // Idem para a tradução: o alvo entra no config do WebSocket e não pode
    // trocar no meio de uma captura.
    ref.listen(translationProvider, (_, _) {
      _scheduleSessionRebuild();
      _notifyPendingSetting();
    });
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      // No Android a janela é edge-to-edge: sem SafeArea o cabeçalho "Perfil"
      // fica atrás da barra de status/recorte e a tab bar atrás da barra de
      // gestos. No macOS os insets são zero, então nada muda.
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _content()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CupertinoTabBar(
                currentIndex: currentPage,
                onTap: (value) {
                  setState(() => currentPage = value);
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.house),
                    activeIcon: Icon(CupertinoIcons.house_fill),
                    label: 'Início',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.text_alignleft),
                    activeIcon: Icon(CupertinoIcons.text_alignleft),
                    label: 'Sandbox',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.clock),
                    activeIcon: Icon(CupertinoIcons.clock_fill),
                    label: 'Histórico',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    return switch (currentPage) {
      _homeTab => _homePage(),
      _sandboxTab => _sandboxPage(),
      _ => const TranscriptionsHistory(),
    };
  }

  Widget _homePage() {
    // Keying the settings by profile remounts them on switch, so each one
    // reloads its values.
    final profileId = ref.watch(activeProfileIdProvider);
    final hasApiKey = ref.watch(apiKeyProvider).isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: kSectionSpacing,
        children: [
          ProfileSelector(),
          if (!hasApiKey) _missingApiKeyNotice(),
          ApiKeySetter(key: ValueKey('api-key-$profileId')),
          DevicePicker(key: ValueKey('device-$profileId'), recorder: recorder),
          TermsPicker(),
          LanguagePicker(),
          TranslationSettings(key: ValueKey('home-translation')),
          ContextTextSetter(key: ValueKey('context-$profileId')),
        ],
      ),
    );
  }

  /// A aba da sandbox: captura comandada pelo botão (sempre visível, nas duas
  /// plataformas), o acesso aos ajustes da captura e a caixa onde o texto ao
  /// vivo aparece.
  ///
  /// Sem rolagem na página: a caixa ocupa toda a altura que sobra da aba (a
  /// barra inferior flutua sobre o conteúdo, daí o recuo de 58 px no rodapé).
  Widget _sandboxPage() {
    final hasApiKey = ref.watch(apiKeyProvider).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 58),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _recordControl(hasApiKey),
          const SizedBox(height: kSectionSpacing),
          Expanded(child: _textAreas()),
        ],
      ),
    );
  }

  /// As caixas de texto da aba: a transcrição e, com a tradução ligada, a
  /// tradução embaixo dela. A tradução divide a altura com a transcrição em vez
  /// de virar uma terceira aba — as duas são lidas juntas.
  Widget _textAreas() {
    final target = ref.watch(translationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: target == null ? 1 : 3, child: _sandbox()),
        if (target != null) ...[
          const SizedBox(height: kSectionSpacing),
          Expanded(flex: 2, child: _translation(target)),
        ],
      ],
    );
  }

  /// Caixa da tradução: só leitura (quem escreve é o Soniox), com a língua alvo
  /// no cabeçalho e a mesma ação de copiar da sandbox.
  Widget _translation(Language target) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              Text('Tradução — ${target.label}', style: sectionLabelStyle),
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _translationController,
                builder: (context, value, _) {
                  return _sandboxAction(
                    key: const ValueKey('sandbox-translation-copy'),
                    label: 'Copiar',
                    icon: CupertinoIcons.doc_on_doc,
                    onPressed: value.text.isEmpty ? null : _copyTranslation,
                  );
                },
              ),
            ],
          ),
        ),
        if (_showNothingToTranslate) ...[
          const SizedBox(height: 2),
          Text(
            'Nada para traduzir: a fala já está em ${target.label}.',
            key: const ValueKey('sandbox-translation-empty'),
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.tertiaryLabel,
            ),
          ),
        ],
        const SizedBox(height: kLabelSpacing),
        Expanded(
          child: CupertinoTextField(
            key: const ValueKey('sandbox-translation-field'),
            controller: _translationController,
            readOnly: true,
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            placeholder: 'A tradução aparece aqui durante a captura.',
            padding: const EdgeInsets.all(12),
            decoration: fieldDecoration(),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _missingApiKeyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: CupertinoColors.systemOrange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              PlatformSupport.supportsGlobalHotkey
                  ? 'Este perfil não tem chave Soniox. O atalho não vai gravar '
                        'até que uma chave seja definida.'
                  : 'Este perfil não tem chave Soniox. Gravar não vai '
                        'funcionar até que uma chave seja definida.',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Comando de captura por toque/clique, com o acesso aos ajustes da captura
  /// no fim da mesma linha. Fica logo acima da sandbox porque é ali que o texto
  /// desta sessão vai aparecer (e no Android é o único jeito de abrir uma
  /// sessão).
  Widget _recordControl(bool hasApiKey) {
    return Row(
      children: [
        Expanded(
          child: RecordButton(
            isRecording: _recording,
            pointerVerb: PlatformSupport.usesClickVerb ? 'Clique' : 'Toque',
            onPressed: () => _toggleRecording(hasApiKey),
          ),
        ),
        const SizedBox(width: 8),
        _captureSettingsButton(),
      ],
    );
  }

  /// Ajustes da captura (diarização e tradução) num popup: na aba, cada opção
  /// virava uma linha e as duas empurravam a caixa de texto para baixo.
  Widget _captureSettingsButton() {
    return CupertinoButton(
      key: const ValueKey('sandbox-settings'),
      padding: EdgeInsets.zero,
      pressedOpacity: 0.6,
      onPressed: () => showSandboxSettings(context),
      child: Container(
        height: 52,
        width: 52,
        alignment: Alignment.center,
        decoration: fieldDecoration(radius: 12),
        child: const Icon(
          CupertinoIcons.settings,
          size: 20,
          color: CupertinoColors.secondaryLabel,
        ),
      ),
    );
  }

  Widget _sandbox() {
    // O header com as ações acompanha o conteúdo: os botões ficam desabilitados
    // enquanto a sandbox está vazia, e para isso a UI precisa saber do texto.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              const Text('Sandbox', style: sectionLabelStyle),
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _sandboxController,
                builder: (context, value, _) {
                  final isEmpty = value.text.isEmpty;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sandboxAction(
                        key: const ValueKey('sandbox-copy'),
                        label: 'Copiar',
                        icon: CupertinoIcons.doc_on_doc,
                        onPressed: isEmpty ? null : _copySandbox,
                      ),
                      const SizedBox(width: 4),
                      _sandboxAction(
                        key: const ValueKey('sandbox-clear'),
                        label: 'Limpar',
                        icon: CupertinoIcons.trash,
                        onPressed: isEmpty ? null : _clearSandbox,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: kLabelSpacing),
        Expanded(
          child: CupertinoTextField(
            key: const ValueKey('sandbox-field'),
            controller: _sandboxController,
            focusNode: _sandboxFocusNode,
            // `expands` exige minLines/maxLines nulos: a caixa cresce com a
            // aba e o texto rola dentro dela quando passa da altura.
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            padding: const EdgeInsets.all(12),
            decoration: fieldDecoration(),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  /// Ação do header da sandbox. `onPressed: null` desabilita (CupertinoButton
  /// cuida da cor apagada) — a ação só existe quando há o que copiar/apagar.
  Widget _sandboxAction({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return CupertinoButton(
      key: key,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.5,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _copySandbox() {
    final text = _sandboxController.text;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    showToast(context, 'Sandbox copiada para a área de transferência.');
  }

  void _clearSandbox() {
    _setSandboxText('');
    // A tradução é da mesma captura: limpar a sandbox sem limpar ela deixaria
    // um texto órfão na tela.
    _setTranslationText('');
    // Limpar é para recomeçar a digitar: devolve o foco ao campo.
    _sandboxFocusNode.requestFocus();
  }

  void _copyTranslation() {
    final text = _translationController.text;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    showToast(context, 'Tradução copiada para a área de transferência.');
  }

  /// Inserts [text] into the sandbox field at the current cursor position,
  /// replacing any selection. Invoked by the native side when the transcription
  /// finishes while this app is in the foreground.
  void _insertIntoSandbox(String text) {
    final value = _sandboxController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final newText = value.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    final newOffset = selection.start + text.length;
    _sandboxController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    // A sandbox agora é uma aba: sem trocar para ela o texto entraria num campo
    // que o usuário não está vendo (falha silenciosa).
    if (currentPage != _sandboxTab && mounted) {
      setState(() => currentPage = _sandboxTab);
    }
    _sandboxFocusNode.requestFocus();
  }

  // MARK: Events

  bool _rebuildScheduled = false;

  void _scheduleSessionRebuild() {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    scheduleMicrotask(() {
      _rebuildScheduled = false;
      if (mounted) _updateSonioxInstance();
    });
  }

  /// Opção de sessão mexida com uma captura em andamento: a conexão atual não
  /// muda, então a pessoa precisa saber que só vale na próxima — senão a
  /// tradução (por exemplo) fica sem texto e parece defeito.
  void _notifyPendingSetting() {
    if (!_isProcessing || !mounted) return;
    showToast(context, 'Vale a partir da próxima captura.');
  }

  void _updateSonioxInstance() {
    // A recording is in flight: key-up rebuilds the session from the current
    // providers right after, so don't tear it down now.
    if (_isProcessing) return;
    final apiKey = ref.read(apiKeyProvider);

    // Reset
    hotkeyListener.onKeyDown = () {};
    hotkeyListener.onKeyUp = () {};
    _resetSessionState();
    soniox?.disconnect();
    recorder.stop();
    _connectionSubscription?.cancel();
    _recordStreamSubscription?.cancel();
    _transcriptionSubscription?.cancel();
    _errorSubscription?.cancel();
    _recorderErrorSubscription?.cancel();

    if (apiKey.isEmpty) {
      return;
    }

    // Updating state
    debugPrint('Creating soniox websocket with api key');
    final sessionConfig = buildSessionConfig(
      apiKey: apiKey,
      languages: ref.read(languagesProvider).map((x) => x.name).toList(),
      speakerDiarization: ref.read(diarizationProvider),
      translationTarget: ref.read(translationProvider),
      contextText: ref.read(contextProvider),
      terms: ref.read(termsProvider),
    );
    var current = soniox = SonioxWebsocket(
      sessionConfig,
      websocket: createWebsocket(),
    );

    _connectionSubscription = current.connectionStream.listen((connect) async {
      debugPrint('Connected! $connect');
      if (connect) {
        HotkeyListener.setListening();
        await recorder.start();
        if (!_isProcessing || !identical(current, soniox)) {
          // The key was released while the capture was being (re)started.
          await recorder.stop();
          return;
        }
        debugPrint('Recording...');
        _recordStreamSubscription = recorder.recordStream.listen((data) {
          current.addAudio(data);
        });
      } else {
        _recordStreamSubscription?.cancel();
      }
    });

    // The capture can fail (or die silently) without touching Soniox: report it
    // instead of leaving the user with an empty transcription.
    _recorderErrorSubscription = recorder.errors.listen((message) {
      if (!_isProcessing || _sessionError != null) {
        return;
      }
      _sessionError = message;
      _failSession(message);
      _recordStreamSubscription?.cancel();
    });

    // A tecla global existe apenas no macOS, e lá é ela o transporte da sessão.
    // Nas outras plataformas o botão de gravar chama estes mesmos métodos.
    if (PlatformSupport.supportsGlobalHotkey) {
      hotkeyListener.onKeyDown = _startSession;
      hotkeyListener.onKeyUp = _finishSession;
    }
  }

  void _resetSessionState() {
    _buffer.clear();
    _nonFinal = '';
    _sessionError = null;
    _diarized = null;
    _translationTarget = null;
    _translationBuffer.clear();
    _nonFinalTranslation = '';
    _translationLogged = false;
    _translationErrorReported = false;
    _untranslatedSpeech = false;
    _showNothingToTranslate = false;
  }

  // MARK: Sessão (transporte independente de plataforma)

  /// Abre a captura. Chamado pela tecla global (macOS) ou pelo botão de gravar.
  ///
  /// [fromButton] decide o DESTINO do texto: sessão do botão entrega na sandbox
  /// (em qualquer plataforma); sessão da tecla global, no macOS, cola no app em
  /// foco e mostra o painel flutuante.
  void _startSession({bool fromButton = false}) {
    _sessionFromButton = fromButton;
    final current = soniox;
    if (current == null) {
      _reportError(
        'Nenhuma chave Soniox no perfil ativo. Salve a chave antes de gravar.',
      );
      return;
    }
    if (_isProcessing) return;
    _isProcessing = true;
    _recording = true;
    if (mounted) setState(() {});

    _sandboxBaseText = _sandboxController.text;
    // Diarização congela no início da sessão: mudar a caixa no meio de uma
    // captura não pode trocar o formato do texto que já está sendo escrito.
    _diarized = ref.read(diarizationProvider) ? DiarizedTextBuilder() : null;
    // A tradução também é parâmetro de conexão: congela aqui e o texto da
    // captura anterior sai da tela.
    _translationTarget = ref.read(translationProvider);
    _setTranslationText('');

    // Sessão do botão já mostra o andamento na própria sandbox: o painel
    // flutuante é do caminho da tecla global, que roda longe do app.
    if (!_sessionFromButton) HotkeyListener.showOverlay();

    _transcriptionSubscription?.cancel();
    // Com tradução ligada a origem é a mensagem CRUA do WebSocket: só ela traz
    // `translation_status`, e sem separar por ele o texto traduzido entraria
    // misturado na transcrição.
    _transcriptionSubscription = _translationTarget == null
        ? current.transcription.listen(_onTranscription)
        : current.rawMessages.listen(_onTranslationMessage);
    debugPrint(
      '[session] tradução: ${_translationTarget?.name ?? 'desligada'} | '
      'diarização: ${_diarized != null} | eventos: '
      '${_translationTarget == null ? 'transcription' : 'rawMessages'}',
    );

    _errorSubscription?.cancel();
    _errorSubscription = current.errors.listen((sonioxError) {
      if (_sessionError != null) return;
      final error = _describeSonioxError(sonioxError);
      _sessionError = error;
      debugPrint('Soniox error: $error');
      _failSession(error);
      _recordStreamSubscription?.cancel();
      recorder.stop();
    });

    current.connect();
    debugPrint('Connect command');
  }

  /// Andamento de uma sessão sem tradução: o pacote já entrega o texto pronto.
  void _onTranscription(SonioxTranscription transcription) {
    final diarized = _diarized;
    if (diarized == null) {
      _buffer.write(transcription.finalText);
    } else {
      _buffer.write(
        diarized.take(
          transcription.finalTokens,
          // Base da sandbox ou falas anteriores: define a quebra de linha antes
          // do primeiro rótulo de falante.
          followsText: _sandboxBaseText.isNotEmpty || _buffer.isNotEmpty,
        ),
      );
    }
    _nonFinal = transcription.nonFinalText;
    _showLiveText();
  }

  /// Andamento de uma sessão com tradução: o evento já vem separado em
  /// transcrição e tradução, então os dois textos crescem no lugar certo.
  void _onTranslationMessage(String raw) {
    final TranslatedEvent? event;
    try {
      event = TranslatedEvent.fromRawMessage(raw);
    } catch (error, stack) {
      // Sem este catch, uma exceção aqui cancelaria a assinatura e a tradução
      // ficaria vazia para sempre, sem sinal nenhum na tela.
      _reportTranslationFailure('$error', stack);
      return;
    }
    if (event == null) return;

    final diarized = _diarized;
    if (diarized == null) {
      _buffer.write(event.finalOriginals.map((token) => token.text).join());
    } else {
      _buffer.write(
        diarized.take(
          event.finalOriginals,
          followsText: _sandboxBaseText.isNotEmpty || _buffer.isNotEmpty,
        ),
      );
    }
    _nonFinal = event.nonFinalOriginals.map((token) => token.text).join();
    if (event.hasUntranslatedSpeech) _untranslatedSpeech = true;
    _translationBuffer.write(event.finalTranslation);
    _nonFinalTranslation = event.nonFinalTranslation;
    if (!_translationLogged && _translationBuffer.isNotEmpty) {
      _translationLogged = true;
      debugPrint('[session] primeira tradução recebida: $_translationBuffer');
    }
    _refreshNothingToTranslate();
    _showLiveText();
  }

  /// Ligado quando o Soniox transcreveu sem traduzir (fala já no idioma alvo).
  /// Só muda o estado do widget quando o aviso realmente entra ou sai.
  void _refreshNothingToTranslate() {
    final shouldShow =
        _translationTarget != null &&
        _untranslatedSpeech &&
        _translationBuffer.isEmpty &&
        _nonFinalTranslation.isEmpty;
    if (shouldShow == _showNothingToTranslate) return;
    _showNothingToTranslate = shouldShow;
    if (mounted) setState(() {});
  }

  /// Falha do caminho da tradução: aparece uma vez por sessão (toast) e vai para
  /// o log com a stack — o resto da captura continua.
  void _reportTranslationFailure(String error, StackTrace stack) {
    debugPrint('[session] falha ao ler evento cru: $error\n$stack');
    if (_translationErrorReported) return;
    _translationErrorReported = true;
    if (!mounted) return;
    showToast(context, 'Falha ao processar a tradução: $error');
  }

  /// Fecha a captura e entrega o texto: colado no app em foco (tecla global no
  /// macOS) ou deixado na sandbox + área de transferência (sessão do botão, em
  /// qualquer plataforma).
  void _finishSession() {
    if (!_isProcessing) return;

    final finalText = _buffer.toString();
    final fullText = finalText + _nonFinal;
    final hadError = _sessionError != null;

    // Keep an error on screen long enough to read after the key is released.
    if (!_sessionFromButton) {
      HotkeyListener.hideOverlay(
        delay: hadError ? const Duration(seconds: 4) : null,
      );
    }

    if (fullText.isNotEmpty) {
      GetIt.I.get<TranscriptionRepository>().insert(
        TranscriptionRecord(
          finalText: finalText,
          nonFinalText: _nonFinal,
          createdAt: DateTime.now(),
        ),
      );
      ref.invalidate(historyProvider);
      if (_sessionFromButton) {
        _deliverToSandbox(fullText);
      } else {
        HotkeyListener.pasteText(fullText);
      }
    }
    soniox?.disconnect();
    recorder.stop();
    _isProcessing = false;
    _recording = false;
    _sessionFromButton = false;
    if (mounted) setState(() {});
    _updateSonioxInstance();
  }

  /// Liga/desliga a captura pelo botão (existe nas duas plataformas).
  Future<void> _toggleRecording(bool hasApiKey) async {
    if (!hasApiKey) {
      showToast(context, 'Salve a chave Soniox do perfil para gravar.');
      return;
    }
    if (_recording) {
      _finishSession();
      return;
    }
    // O diálogo de permissão do sistema aparece aqui: pedir dentro da sessão
    // gastaria uma conexão com a Soniox só para descobrir que falta o microfone.
    final allowed = await recorder.requestMicPermission();
    if (!allowed) {
      if (mounted) {
        showToast(context, RecorderRepository.permissionDeniedMessage);
      }
      return;
    }
    if (!mounted) return;
    _startSession(fromButton: true);
  }

  /// Andamento da transcrição: painel flutuante na sessão da tecla global;
  /// sessão do botão (e plataformas sem painel) escreve na própria sandbox.
  void _showLiveText() {
    final finalText = _buffer.toString();
    // A tradução é a mesma coisa nas duas rotas: ela fica na aba Sandbox, para
    // conferir (e copiar) depois — o painel da tecla global só mostra o
    // transcript.
    if (_translationTarget != null) {
      _setTranslationText('$_translationBuffer$_nonFinalTranslation');
    }
    if (!_sessionFromButton) {
      HotkeyListener.updateTranscription(finalText, _nonFinal);
      return;
    }
    _setSandboxText('$_sandboxBaseText$finalText$_nonFinal');
  }

  /// Erro visível: painel flutuante na sessão da tecla global, toast dentro do
  /// app quando é o usuário que está olhando a tela.
  void _reportError(String message) {
    if (!_sessionFromButton && PlatformSupport.supportsGlobalHotkey) {
      HotkeyListener.showError(message);
      return;
    }
    if (!mounted) return;
    showToast(context, message);
  }

  /// Erro no meio da sessão. Sem tecla global (ou na sessão do botão) não há
  /// "soltar a tecla" para encerrar a captura: fecha a sessão aqui mesmo, senão
  /// o botão ficaria preso em "Ouvindo…" sem nada chegando.
  void _failSession(String message) {
    _reportError(message);
    if (_sessionFromButton || !PlatformSupport.supportsGlobalHotkey) {
      _finishSession();
    }
  }

  /// Resultado final da sessão do botão: fica na sandbox e vai para a área de
  /// transferência, pronta para outro app.
  void _deliverToSandbox(String text) {
    _setSandboxText('$_sandboxBaseText$text');
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showToast(context, 'Transcrição copiada para a área de transferência.');
    }
  }

  void _setSandboxText(String text) {
    _sandboxController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _setTranslationText(String text) {
    _translationController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _describeSonioxError(SonioxError error) {
    return switch (error.code) {
      401 => 'Chave Soniox inválida. Verifique a chave do perfil.',
      // vit_soniox reports a failed connection with code 0.
      0 => 'Não foi possível conectar à Soniox: ${error.message}',
      _ => 'Erro Soniox (${error.code}): ${error.message}',
    };
  }
}
