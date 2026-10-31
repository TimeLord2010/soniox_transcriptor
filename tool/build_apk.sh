#!/usr/bin/env bash
#
# Gera o APK de release SÓ para aparelhos recentes (arm64).
#
# Um artefato só: nada de APK universal (carrega motor de várias ABIs e incha) e
# nada de `--split-per-abi` (o usuário teria que escolher o arquivo certo). O
# `android/app/build.gradle.kts` também exclui as pastas de 32 bits, então um
# aparelho antigo nem se declara compatível.
#
# Uso:  tool/build_apk.sh
# Saída: build/app/outputs/flutter-apk/app-release.apk
#        build/symbols/  (símbolos de desofuscação — GUARDAR junto do APK)
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SYMBOLS_DIR="build/symbols"
APK="build/app/outputs/flutter-apk/app-release.apk"

# O Gradle do Android precisa de um JDK; o `java` do PATH nesta máquina é o stub
# da Apple ("Unable to locate a Java Runtime"). Procura um de verdade sem mexer
# na configuração global do flutter.
find_jdk() {
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    echo "$JAVA_HOME"
    return
  fi
  if /usr/libexec/java_home >/dev/null 2>&1; then
    /usr/libexec/java_home
    return
  fi
  local candidate
  for candidate in \
    /opt/homebrew/opt/openjdk*/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk*/libexec/openjdk.jdk/Contents/Home \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home"; do
    if [ -x "$candidate/bin/java" ]; then
      echo "$candidate"
      return
    fi
  done
}

JDK="$(find_jdk || true)"
if [ -z "$JDK" ]; then
  echo "ERRO: nenhum JDK encontrado (brew install openjdk@17, ou flutter config --jdk-dir)." >&2
  exit 1
fi
export JAVA_HOME="$JDK"
export PATH="$JAVA_HOME/bin:$PATH"

flutter pub get
# Símbolos de um build anterior não desofuscam este: sempre do zero.
rm -rf "$SYMBOLS_DIR"

flutter build apk --release \
  --target-platform android-arm64 \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR"

if [ ! -f "$APK" ]; then
  echo "ERRO: APK não foi gerado em $APK" >&2
  exit 1
fi

# aapt2 prova o que o APK declara: ABIs compiladas e versões mínima/alvo.
find_aapt2() {
  if command -v aapt2 >/dev/null 2>&1; then
    command -v aapt2
    return
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  ls "$sdk"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1
}

echo
echo "APK.........: $APK"
echo "Tamanho.....: $(du -h "$APK" | awk '{print $1}')"
echo "Símbolos....: $SYMBOLS_DIR (guardar para desofuscar stack traces)"
echo "JDK.........: $JAVA_HOME"

AAPT="$(find_aapt2 || true)"
if [ -n "$AAPT" ]; then
  echo "--- badging ---"
  "$AAPT" dump badging "$APK" |
    grep -E "^(package:|[Mm]in[Ss]dkVersion:|[Ss]dkVersion:|targetSdkVersion:|native-code:|application-label:)" || true
else
  echo "(aapt2 não encontrado — sem badging; APK gerado mesmo assim)"
fi
