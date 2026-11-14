import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soniox_transcriptor/models/languages.dart';
import 'package:soniox_transcriptor/modules/control_tokens.dart';
import 'package:soniox_transcriptor/modules/diarized_text.dart';
import 'package:soniox_transcriptor/modules/soniox_error_text.dart';
import 'package:soniox_transcriptor/modules/translated_event.dart';
import 'package:soniox_transcriptor/repositories/recorder_repository.dart';
import 'package:vit_soniox/vit_soniox.dart';

/// O que a camada de UI faz quando a sessão pede alguma coisa.
///
/// O controlador não conhece `BuildContext`: painel flutuante, sandbox, toast,
/// histórico e entrega do texto são do app, que implementa esta interface.
abstract class SessionHost {
  /// Sessão da tecla global: o resultado aparece no painel flutuante.
  void onShowOverlay();
  void onHideOverlay({required bool hadError});
  void onOverlayText(String finalText, String nonFinal);

  /// Conectou: o painel passa a mostrar "ouvindo".
  void onConnectionEstablished();

  /// Texto ao vivo da sessão do botão (a sandbox acompanha a captura).
  void onSandboxText(String text);
  void onTranslationText(String text);

  /// O aviso "nada para traduzir" entrou ou saiu.
  void onNothingToTranslateChanged();

  /// Falha ao ler o evento cru da tradução (uma vez por sessão).
  void onTranslationFailure(String message);

  /// Erro que o usuário está olhando na tela (toast).
  void onError(String message);

  /// A sessão fechou com texto: gravar no histórico e entregar é do app.
  /// [sandboxBaseText] é o conteúdo que já estava na sandbox quando a captura
  /// começou — o resultado entra depois dele, sem apagar o que a pessoa digitou.
  void onCompleted(String finalText, String nonFinal, String sandboxBaseText);

  /// `_recording`/`_isProcessing` mudaram (o botão precisa repintar).
  void onStateChanged();

  /// A sessão terminou; o app reconstrói a conexão com os ajustes atuais.
  void onClosed();
}

/// A sessão de captura: buffer do texto, diarização, tradução e a máquina de
/// estados que a tecla global (macOS) e o botão de gravar compartilham.
///
/// Vive fora do widget para poder ser exercitada sem árvore de widgets: o
/// gravador e a conexão entram por parâmetro, e as decisões de tela saem pelo
/// [SessionHost].
class SessionController {
  SessionController({
    required this.host,
    required this.recorder,
    required this.supportsOverlay,
    required this.diarizationEnabled,
    required this.translationTarget,
  });

  final SessionHost host;
  final RecorderRepository recorder;

  /// A plataforma desenha o painel flutuante (macOS). Sem ele, erro é toast e a
  /// sessão se encerra sozinha em vez de esperar a tecla subir.
  final bool supportsOverlay;

  /// Opções lidas do perfil no momento em que a captura abre.
  final bool Function() diarizationEnabled;
  final Language? Function() translationTarget;

  SonioxWebsocket? _connection;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<List<int>>? _recordStreamSubscription;
  StreamSubscription? _transcriptionSubscription;
  StreamSubscription<SonioxError>? _errorSubscription;
  StreamSubscription<String>? _recorderErrorSubscription;

  bool _isProcessing = false;
  bool _recording = false;

  /// A sessão foi aberta pelo botão de gravar em vez da tecla global. Nesse
  /// caso o destino é a sandbox em qualquer plataforma — inclusive no macOS,
  /// onde a tecla global cola no app em foco (que seria o próprio app).
  bool _sessionFromButton = false;

  final _buffer = StringBuffer();
  String _nonFinal = '';
  String? _sessionError;

  /// Conteúdo da sandbox quando a captura começou; o texto ao vivo é somado a
  /// ele em vez de sobrescrever o que o usuário tinha digitado.
  String _sandboxBaseText = '';

  /// Preenchido só na sessão com diarização ligada: monta o texto final com o
  /// rótulo do falante. Criado por sessão para zerar o falante corrente.
  DiarizedTextBuilder? _diarized;

  /// Língua alvo congelada no início da sessão (`null` = tradução desligada).
  /// Como a diarização, é parâmetro de conexão: mudar a opção no meio da
  /// captura só vale na próxima.
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

  bool get isRecording => _recording;
  bool get isProcessing => _isProcessing;
  bool get sessionFromButton => _sessionFromButton;
  bool get showNothingToTranslate => _showNothingToTranslate;

  /// Existe conexão pronta: é o que liga a tecla global.
  bool get canStart => _connection != null;

  /// Instala a conexão da vez (ou nenhuma, quando o perfil está sem chave).
  ///
  /// Chamado pela UI quando chave/perfil/ajustes mudam — com uma captura em
  /// andamento não faz nada: o fim da captura reconstrói com os valores atuais.
  void rebuild(SonioxWebsocket? connection) {
    if (_isProcessing) return;

    // Reset
    _resetSessionState();
    _connection?.disconnect();
    recorder.stop();
    _connectionSubscription?.cancel();
    _recordStreamSubscription?.cancel();
    _transcriptionSubscription?.cancel();
    _errorSubscription?.cancel();
    _recorderErrorSubscription?.cancel();
    _connection = connection;

    if (connection == null) return;

    _connectionSubscription = connection.connectionStream.listen((
      connect,
    ) async {
      debugPrint('Connected! $connect');
      if (connect) {
        host.onConnectionEstablished();
        await recorder.start();
        if (!_isProcessing || !identical(connection, _connection)) {
          // The key was released while the capture was being (re)started.
          await recorder.stop();
          return;
        }
        debugPrint('Recording...');
        _recordStreamSubscription = recorder.recordStream.listen(
          connection.addAudio,
        );
      } else {
        unawaited(_recordStreamSubscription?.cancel());
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
  }

  /// Abre a captura. Chamado pela tecla global (macOS) ou pelo botão de gravar.
  ///
  /// [fromButton] decide o DESTINO do texto: sessão do botão entrega na sandbox
  /// (em qualquer plataforma); sessão da tecla global, no macOS, cola no app em
  /// foco e mostra o painel flutuante.
  void startSession({bool fromButton = false, String sandboxBaseText = ''}) {
    _sessionFromButton = fromButton;
    final current = _connection;
    if (current == null) {
      host.onError(
        'Nenhuma chave Soniox no perfil ativo. Salve a chave antes de gravar.',
      );
      return;
    }
    if (_isProcessing) return;
    _isProcessing = true;
    _recording = true;
    host.onStateChanged();

    _sandboxBaseText = sandboxBaseText;
    // Diarização congela no início da sessão: mudar a caixa no meio de uma
    // captura não pode trocar o formato do texto que já está sendo escrito.
    _diarized = diarizationEnabled() ? DiarizedTextBuilder() : null;
    // A tradução também é parâmetro de conexão: congela aqui e o texto da
    // captura anterior sai da tela.
    _translationTarget = translationTarget();
    host.onTranslationText('');

    // Sessão do botão já mostra o andamento na própria sandbox: o painel
    // flutuante é do caminho da tecla global, que roda longe do app.
    if (!_sessionFromButton) host.onShowOverlay();

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
      final error = describeSonioxError(sonioxError);
      _sessionError = error;
      debugPrint('Soniox error: $error');
      _failSession(error);
      _recordStreamSubscription?.cancel();
      recorder.stop();
    });

    current.connect();
    debugPrint('Connect command');
  }

  /// Fecha a captura e entrega o texto: colado no app em foco (tecla global no
  /// macOS) ou deixado na sandbox + área de transferência (sessão do botão, em
  /// qualquer plataforma).
  void finishSession() {
    if (!_isProcessing) return;

    final finalText = _buffer.toString();
    final fullText = finalText + _nonFinal;
    final hadError = _sessionError != null;

    // Keep an error on screen long enough to read after the key is released.
    if (!_sessionFromButton) host.onHideOverlay(hadError: hadError);

    if (fullText.isNotEmpty) {
      host.onCompleted(finalText, _nonFinal, _sandboxBaseText);
    }

    _connection?.disconnect();
    recorder.stop();
    _isProcessing = false;
    _recording = false;
    _sessionFromButton = false;
    host.onStateChanged();
    host.onClosed();
  }

  void dispose() {
    _connection?.disconnect();
    _connectionSubscription?.cancel();
    _recordStreamSubscription?.cancel();
    _transcriptionSubscription?.cancel();
    _errorSubscription?.cancel();
    _recorderErrorSubscription?.cancel();
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

  /// Andamento de uma sessão sem tradução: o pacote já entrega o texto pronto.
  void _onTranscription(SonioxTranscription transcription) {
    final diarized = _diarized;
    if (diarized == null) {
      // O pacote entrega o texto concatenado, marcadores incluídos.
      _buffer.write(withoutControlTokens(transcription.finalText));
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
    _nonFinal = withoutControlTokens(transcription.nonFinalText);
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
  /// Só avisa a UI quando o estado do aviso realmente muda.
  void _refreshNothingToTranslate() {
    final shouldShow =
        _translationTarget != null &&
        _untranslatedSpeech &&
        _translationBuffer.isEmpty &&
        _nonFinalTranslation.isEmpty;
    if (shouldShow == _showNothingToTranslate) return;
    _showNothingToTranslate = shouldShow;
    host.onNothingToTranslateChanged();
  }

  /// Falha do caminho da tradução: aparece uma vez por sessão e vai para o log
  /// com a stack — o resto da captura continua.
  void _reportTranslationFailure(String error, StackTrace stack) {
    debugPrint('[session] falha ao ler evento cru: $error\n$stack');
    if (_translationErrorReported) return;
    _translationErrorReported = true;
    host.onTranslationFailure(error);
  }

  /// Andamento da transcrição: painel flutuante na sessão da tecla global;
  /// sessão do botão (e plataformas sem painel) escreve na própria sandbox.
  void _showLiveText() {
    final finalText = _buffer.toString();
    // A tradução é a mesma coisa nas duas rotas: ela fica na aba Sandbox, para
    // conferir (e copiar) depois — o painel da tecla global só mostra o
    // transcript.
    if (_translationTarget != null) {
      host.onTranslationText('$_translationBuffer$_nonFinalTranslation');
    }
    if (!_sessionFromButton) {
      host.onOverlayText(finalText, _nonFinal);
      return;
    }
    host.onSandboxText('$_sandboxBaseText$finalText$_nonFinal');
  }

  /// Erro no meio da sessão. Sem painel flutuante (ou na sessão do botão) não
  /// há "soltar a tecla" para encerrar a captura: fecha a sessão aqui mesmo,
  /// senão o botão ficaria preso em "Ouvindo…" sem nada chegando.
  void _failSession(String message) {
    host.onError(message);
    if (_sessionFromButton || !supportsOverlay) {
      finishSession();
    }
  }
}
