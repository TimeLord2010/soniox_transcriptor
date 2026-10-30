# soniox_transcriptor

Transcrição em tempo real via Soniox, com perfis (chave, termos, idiomas e
contexto por perfil).

## Plataformas

| Plataforma | Papel | Como a captura começa | Onde o texto vai |
| --- | --- | --- | --- |
| macOS | alvo principal | tecla global (Option direito), com painel flutuante; ou botão **Clique para gravar** | tecla: colado no app em foco · botão: sandbox + área de transferência |
| Android | alvo secundário | botão **Toque para gravar** | sandbox + área de transferência |

O macOS é um app de bandeja: fica em segundo plano e o usuário segura a tecla
global em qualquer app; um pop‑up discreto mostra a transcrição e o texto final
é injetado na caixa de texto em foco.

No Android **não existe tecla global nem colagem em outro app** (isso exigiria
um teclado ou serviço de acessibilidade próprio). Ali a captura é comandada por
toque: o botão abre e fecha a sessão, o texto aparece ao vivo na sandbox e o
resultado final também fica na área de transferência. Perfis, chave Soniox,
termos, idiomas, contexto, dispositivos de entrada e histórico funcionam igual
nas duas plataformas.

A **sandbox é uma aba própria** (Início · Sandbox · Histórico), com o botão de
gravar sempre visível acima da caixa e as ações Copiar/Limpar no cabeçalho. A
sessão aberta pelo botão entrega o texto na sandbox em qualquer plataforma — no
macOS inclusive, já que ali o app em foco seria o próprio app.

O checkbox **Diarização** (também na aba da sandbox, salvo por perfil) liga
`enable_speaker_diarization` na sessão: o texto final passa a sair com o falante
na frente de cada bloco (`Falante 1: …`, `Falante 2: …`), uma linha por bloco. O
Soniox entrega o falante por token, então quem monta esse formato é o app
(`lib/modules/diarized_text.dart`), não o pacote.

A decisão de capacidade fica em `lib/modules/platform_support.dart` — não
espalhe `Platform.isMacOS` pelo código.

## Build

```bash
# macOS
flutter build macos --release   # build/macos/Build/Products/Release/soniox_transcriptor.app

# Android — SEMPRE arm64 (dispositivos recentes)
flutter build apk --release --target-platform android-arm64 \
  --obfuscate --split-debug-info=build/symbols
# build/app/outputs/flutter-apk/app-release.apk
```

O APK Android é sempre só `arm64-v8a`: o `android/app/build.gradle.kts` exclui as
pastas de 32 bits e de emulador, então o artefato não se declara instalável em
aparelho antigo (que instalaria e morreria sem `libflutter.so`). Todas as libs
nativas estão alinhadas para páginas de 16 KB, exigência das versões recentes do
Android.
