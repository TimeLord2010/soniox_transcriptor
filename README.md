# soniox_transcriptor

Transcrição em tempo real via Soniox, com perfis (chave, termos, idiomas e
contexto por perfil).

## Plataformas

| Plataforma | Papel | Como a captura começa | Onde o texto vai |
| --- | --- | --- | --- |
| macOS | alvo principal | tecla global (Option direito), com painel flutuante | colado no app em foco |
| Android | alvo secundário | botão **Toque para gravar** na tela inicial | sandbox + área de transferência |

O macOS é um app de bandeja: fica em segundo plano e o usuário segura a tecla
global em qualquer app; um pop‑up discreto mostra a transcrição e o texto final
é injetado na caixa de texto em foco.

No Android **não existe tecla global nem colagem em outro app** (isso exigiria
um teclado ou serviço de acessibilidade próprio). Ali a captura é comandada por
toque: o botão abre e fecha a sessão, o texto aparece ao vivo na sandbox e o
resultado final também fica na área de transferência. Perfis, chave Soniox,
termos, idiomas, contexto, dispositivos de entrada e histórico funcionam igual
nas duas plataformas.

A decisão de capacidade fica em `lib/modules/platform_support.dart` — não
espalhe `Platform.isMacOS` pelo código.

## Build

```bash
flutter build macos --release   # build/macos/Build/Products/Release/soniox_transcriptor.app
flutter build apk --release --target-platform android-arm64   # build/app/outputs/flutter-apk/app-release.apk
```
