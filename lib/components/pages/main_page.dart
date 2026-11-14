import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:soniox_transcriptor/components/pages/home_page.dart';
import 'package:soniox_transcriptor/components/pages/sandbox_tab.dart';
import 'package:soniox_transcriptor/components/transcriptions_history.dart';
import 'package:soniox_transcriptor/models/transcription_record.dart';
import 'package:soniox_transcriptor/modules/browser_viewport.dart';
import 'package:soniox_transcriptor/modules/keyboard_session.dart';
import 'package:soniox_transcriptor/modules/platform_support.dart';
import 'package:soniox_transcriptor/modules/session_config.dart';
import 'package:soniox_transcriptor/modules/session_controller.dart';
import 'package:soniox_transcriptor/protocols/show_toast.dart';
import 'package:soniox_transcriptor/providers/api_key_provider.dart';
import 'package:soniox_transcriptor/providers/context_providers.dart';
import 'package:soniox_transcriptor/providers/history_provider.dart';
import 'package:soniox_transcriptor/providers/models_providers.dart';
import 'package:soniox_transcriptor/providers/profile_providers.dart';
import 'package:soniox_transcriptor/repositories/hotkey_listener.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:soniox_transcriptor/repositories/soniox_websocket_impl.dart';
import 'package:soniox_transcriptor/repositories/transcription_repository.dart';
import 'package:vit_soniox/vit_soniox.dart';

/// Casca do app: as três abas, a barra inferior e o encanamento com a sessão de
/// captura ([SessionController]).
///
/// O estado da captura vive no controlador; aqui ficam só as decisões de tela —
/// painel flutuante da tecla global × sandbox, toasts e histórico.
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage>
    with WidgetsBindingObserver
    implements SessionHost {
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

  late final _session = SessionController(
    host: this,
    recorder: recorder,
    supportsOverlay: PlatformSupport.supportsGlobalHotkey,
    diarizationEnabled: () => ref.read(diarizationProvider),
    translationTarget: () => ref.read(translationProvider),
  );

  /// Índices das abas da barra inferior.
  static const int _homeTab = 0;
  static const int _sandboxTab = 1;

  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (PlatformSupport.supportsGlobalHotkey) {
      hotkeyListener.start().catchError((Object e) {
        debugPrint('[MainPage] hotkeyListener.start() error: $e');
      });
    }
    _updateSonioxInstance();
    // O teclado Android lê um blob nas preferências, não os providers: publica
    // o perfil ativo já na abertura do app.
    _publishKeyboardSession();
  }

  /// No navegador, métricas novas (a barra do Safari aparecer/sumir, rotação)
  /// mudam o inset do rodapé. Sem isso a tab bar volta para trás da barra.
  @override
  void didChangeMetrics() {
    if (PlatformSupport.isWeb) setState(() {});
  }

  @override
  void dispose() {
    // The native hotkey monitor is a single, app-global resource. MainPage can
    // mount more than once (a theme/shell rebuild replaces the subtree), and
    // calling the static stop() here would tear down the monitor that a newer,
    // still-alive MainPage just registered. Let it live for the app's
    // lifetime; the OS reclaims it on exit.
    // Não remover: o observer é o único caminho para recalcular o inset do
    // rodapé no navegador.
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    _sandboxController.dispose();
    _sandboxFocusNode.dispose();
    _translationController.dispose();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _listenSessionInputs();
    _listenKeyboardSession();
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      // No Android a janela é edge-to-edge: sem SafeArea o cabeçalho "Perfil"
      // fica atrás da barra de status/recorte e a tab bar atrás da barra de
      // gestos. No macOS os insets são zero, então nada muda.
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A altura que o engine está DESENHANDO é a constraint, não o
            // MediaQuery: com o teclado aberto o Safari encolhe a view e o
            // framework relayouta, mas o MediaQuery do tree fica no valor
            // anterior (medido no aparelho: MediaQuery 699, caixa 396). Medir
            // pelo MediaQuery devolvia inset 303 e espremia a Sandbox em 93 px.
            final surfaceHeight = constraints.maxHeight;
            // No navegador a barra do Safari cobre o rodapé do layout viewport
            // (o engine dimensiona por documentElement.client* e ignora o
            // visualViewport fora de edição de texto). O SafeArea não vê isso
            // no web — o recuo vem do visualViewport, nos três lados.
            final browserPadding = PlatformSupport.isWeb
                ? browserInsets(surfaceHeight: surfaceHeight)
                : EdgeInsets.zero;
            return Padding(
              padding: browserPadding,
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
            );
          },
        ),
      ),
    );
  }

  /// A sessão depende do perfil ativo (chave, termos, idiomas, contexto) e das
  /// opções de conexão: qualquer mudança reconstrói a conexão. As que só valem
  /// na próxima captura avisam a pessoa.
  ///
  /// Coalescido num microtask: chave e perfil podem mudar no mesmo frame.
  void _listenSessionInputs() {
    ref.listen(apiKeyProvider, (_, _) => _scheduleSessionRebuild());
    ref.listen(activeProfileIdProvider, (_, _) => _scheduleSessionRebuild());
    // Diarização, modelo e tradução são parâmetros de sessão: valem na próxima
    // captura, como a chave/termos.
    ref.listen(diarizationProvider, (_, _) {
      _scheduleSessionRebuild();
      _notifyPendingSetting();
    });
    // A primeira resposta da lista de modelos chega depois da abertura do app e
    // cai neste mesmo caminho.
    ref.listen(resolvedModelIdProvider, (_, _) => _scheduleSessionRebuild());
    ref.listen(selectedModelProvider, (_, _) => _notifyPendingSetting());
    ref.listen(translationProvider, (_, _) {
      _scheduleSessionRebuild();
      _notifyPendingSetting();
    });
  }

  /// Reaproveita os mesmos ajustes para republicar o blob do teclado Android:
  /// ele só conhece o perfil ativo pelo que o app escreve nas preferências.
  void _listenKeyboardSession() {
    ref.listen(apiKeyProvider, (_, _) => _publishKeyboardSession());
    ref.listen(activeProfileIdProvider, (_, _) => _publishKeyboardSession());
    ref.listen(contextProvider, (_, _) => _publishKeyboardSession());
    ref.listen(languagesProvider, (_, _) => _publishKeyboardSession());
    ref.listen(termsProvider, (_, _) => _publishKeyboardSession());
    ref.listen(translationProvider, (_, _) => _publishKeyboardSession());
    ref.listen(resolvedModelIdProvider, (_, _) => _publishKeyboardSession());
  }

  Widget _content() {
    return switch (currentPage) {
      _homeTab => HomePage(recorder: recorder),
      _sandboxTab => SandboxTab(
        sandboxController: _sandboxController,
        sandboxFocusNode: _sandboxFocusNode,
        translationController: _translationController,
        translationTarget: ref.watch(translationProvider),
        showNothingToTranslate: _session.showNothingToTranslate,
        isRecording: _session.isRecording,
        pointerVerb: PlatformSupport.usesClickVerb ? 'Clique' : 'Toque',
        onToggleRecording: () =>
            _toggleRecording(ref.read(apiKeyProvider).isNotEmpty),
        onCopySandbox: _copySandbox,
        onClearSandbox: _clearSandbox,
        onCopyTranslation: _copyTranslation,
      ),
      _ => const TranscriptionsHistory(),
    };
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

  // MARK: Conexão

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
    if (!_session.isProcessing || !mounted) return;
    showToast(context, 'Vale a partir da próxima captura.');
  }

  /// Mantém o blob do teclado Android em dia.
  ///
  /// O teclado é nativo e não vê providers: ele lê este JSON das preferências
  /// (`KeyboardSession`), então toda mudança que muda a sessão precisa republicar
  /// — chave, perfil, idiomas, termos, contexto e tradução.
  void _publishKeyboardSession() {
    KeyboardSession.publish(
      model: ref.read(resolvedModelIdProvider),
      apiKey: ref.read(apiKeyProvider),
      languages: ref.read(languagesProvider),
      contextText: ref.read(contextProvider),
      terms: ref.read(termsProvider),
      translationTarget: ref.read(translationProvider),
    ).catchError((Object e) {
      debugPrint('[MainPage] publishKeyboardSession error: $e');
    });
  }

  /// Conexão da vez, montada com os ajustes atuais. `null` = perfil sem chave.
  SonioxWebsocket? _buildConnection() {
    final apiKey = ref.read(apiKeyProvider);
    if (apiKey.isEmpty) return null;
    final sessionConfig = buildSessionConfig(
      model: ref.read(resolvedModelIdProvider),
      apiKey: ref.read(apiKeyProvider),
      languages: ref.read(languagesProvider).map((x) => x.name).toList(),
      speakerDiarization: ref.read(diarizationProvider),
      translationTarget: ref.read(translationProvider),
      contextText: ref.read(contextProvider),
      terms: ref.read(termsProvider),
    );
    return SonioxWebsocket(sessionConfig, websocket: createWebsocket());
  }

  void _updateSonioxInstance() {
    // A recording is in flight: key-up rebuilds the session from the current
    // providers right after, so don't tear it down now.
    if (_session.isProcessing) return;

    // Reset
    hotkeyListener.onKeyDown = () {};
    hotkeyListener.onKeyUp = () {};
    _session.rebuild(_buildConnection());

    // A tecla global existe apenas no macOS, e lá é ela o transporte da sessão.
    // Nas outras plataformas o botão de gravar chama estes mesmos métodos.
    if (PlatformSupport.supportsGlobalHotkey && _session.canStart) {
      hotkeyListener.onKeyDown = _startSession;
      hotkeyListener.onKeyUp = _session.finishSession;
    }
  }

  void _startSession() {
    _session.startSession(sandboxBaseText: _sandboxController.text);
  }

  /// Liga/desliga a captura pelo botão (existe nas duas plataformas).
  Future<void> _toggleRecording(bool hasApiKey) async {
    if (!hasApiKey) {
      showToast(context, 'Salve a chave Soniox do perfil para gravar.');
      return;
    }
    if (_session.isRecording) {
      _session.finishSession();
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
    _session.startSession(
      fromButton: true,
      sandboxBaseText: _sandboxController.text,
    );
  }

  // MARK: SessionHost

  @override
  void onShowOverlay() => HotkeyListener.showOverlay();

  @override
  void onHideOverlay({required bool hadError}) {
    HotkeyListener.hideOverlay(
      delay: hadError ? const Duration(seconds: 4) : null,
    );
  }

  @override
  void onOverlayText(String finalText, String nonFinal) {
    HotkeyListener.updateTranscription(finalText, nonFinal);
  }

  @override
  void onConnectionEstablished() => HotkeyListener.setListening();

  @override
  void onSandboxText(String text) => _setSandboxText(text);

  @override
  void onTranslationText(String text) => _setTranslationText(text);

  @override
  void onNothingToTranslateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void onTranslationFailure(String message) {
    if (!mounted) return;
    showToast(context, 'Falha ao processar a tradução: $message');
  }

  @override
  void onError(String message) {
    // Erro no painel flutuante é da sessão da tecla global; com a pessoa
    // olhando a tela (sessão do botão) o aviso é toast.
    if (!_session.sessionFromButton && PlatformSupport.supportsGlobalHotkey) {
      HotkeyListener.showError(message);
      return;
    }
    if (!mounted) return;
    showToast(context, message);
  }

  @override
  void onCompleted(String finalText, String nonFinal, String sandboxBaseText) {
    GetIt.I.get<TranscriptionRepository>().insert(
      TranscriptionRecord(
        finalText: finalText,
        nonFinalText: nonFinal,
        createdAt: DateTime.now(),
      ),
    );
    ref.invalidate(historyProvider);
    final fullText = finalText + nonFinal;
    if (_session.sessionFromButton) {
      _deliverToSandbox('$sandboxBaseText$fullText');
    } else {
      HotkeyListener.pasteText(fullText);
    }
  }

  @override
  void onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void onClosed() => _updateSonioxInstance();

  /// Resultado final da sessão do botão: fica na sandbox e vai para a área de
  /// transferência, pronta para outro app.
  void _deliverToSandbox(String text) {
    _setSandboxText(text);
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
}
