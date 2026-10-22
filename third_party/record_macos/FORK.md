# record_macos — fork temporário do soniox_transcriptor

Cópia de `record_macos` **1.2.2** (a versão que o `record 6.2.1` traz, ver `pubspec.lock`)
com **uma** correção local: `RecorderStreamDelegate.start()` agora valida o dispositivo
de entrada depois de subir o `AVAudioEngine` e tenta de novo se o sistema tiver trocado
o microfone pelo padrão.

## Por que existe

Com um microfone Bluetooth conectado, o macOS passa a usar o dispositivo Bluetooth como
entrada padrão. O `AVAudioEngine` então aponta o AUHAL de entrada para um agregado privado
(`CADefaultDeviceAggregate-…`) durante o `start()`, **descartando em silêncio** o dispositivo
escolhido via `setDeviceID`. O tap continua preso ao formato do microfone escolhido, nunca
dispara e o app fica sem áudio, sem nenhum erro. Detalhes, medições e proposta de correção
para o upstream: `docs/pr-record-macos-bluetooth-input.md` na raiz do projeto.

## Como o app usa

`pubspec.yaml` do app:

```yaml
dependency_overrides:
  record_macos:
    path: third_party/record_macos
```

## Como remover (quando o fix chegar ao pub.dev)

1. Apagar a entrada `dependency_overrides.record_macos` do `pubspec.yaml` do app.
2. Apagar a pasta `third_party/record_macos`.
3. `flutter pub get` e buildar.

Se o upstream publicar uma versão com o fix, subir o `record` para essa versão é o
caminho; nada no código do app depende desta pasta.

## O que mudou em relação ao 1.2.2

Só `macos/record_macos/Sources/record_macos/delegate/RecorderStreamDelegate.swift`
(mais `version` no `pubspec.yaml` e a remoção de `resolution: workspace`, que não se
aplica a um path dependency fora do workspace do pub). Nada de API: o app continua
chamando `record` do jeito que chamava.
