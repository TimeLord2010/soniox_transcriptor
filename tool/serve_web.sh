#!/usr/bin/env bash
#
# Builda o app para a plataforma web e publica em https://vit-transcriptor.ngrok.app
#
# Sobe duas coisas e mantém as duas no ar até Ctrl+C:
#   1. um servidor estático (python3 http.server) servindo build/web em 127.0.0.1;
#   2. o túnel ngrok apontando para essa porta, no domínio reservado fixo.
# O Ctrl+C (ou qualquer erro) derruba os dois via trap.
#
# Uso:  tool/serve_web.sh
#       WEB_PORT=8090 tool/serve_web.sh          # outra porta local
#       NGROK_DOMAIN=outro.ngrok.app tool/serve_web.sh
#
# URL pública: https://vit-transcriptor.ngrok.app
# Logs: build/web-server.log (estático) e build/ngrok.log (túnel)
#
# Microfone: o navegador só libera getUserMedia em origem segura (https ou
# localhost) — por isso a validação com áudio é pelo domínio do ngrok, não por
# 127.0.0.1. Na primeira visita o ngrok free mostra a página de aviso
# ("You are about to visit..."); passar por ela uma vez libera o site.
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

DOMAIN="${NGROK_DOMAIN:-vit-transcriptor.ngrok.app}"
PORT="${WEB_PORT:-8080}"
WEB_DIR="build/web"
NGROK_LOG="build/ngrok.log"
SERVER_LOG="build/web-server.log"

die() {
  echo "ERRO: $*" >&2
  exit 1
}

for bin in flutter ngrok python3 curl lsof; do
  command -v "$bin" >/dev/null 2>&1 || die "'$bin' não está no PATH."
done

# Porta ocupada = servidor de outra pessoa; falhar aqui é melhor que servir o
# app errado ou deixar o ngrok apontando para um upstream desconhecido.
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  die "a porta $PORT já está em uso. Pare o processo ou rode: WEB_PORT=<outra porta> tool/serve_web.sh"
fi

flutter pub get
flutter build web --release

[ -f "$WEB_DIR/index.html" ] || die "o build web não gerou $WEB_DIR/index.html"

mkdir -p build
rm -f "$NGROK_LOG" "$SERVER_LOG"

SERVER_PID=""
NGROK_PID=""

# Esperar o túnel "começar" no log é a única prova de que a sessão autenticou e
# registrou o domínio — consultar o 4040 não serve, porque um segundo ngrok na
# máquina sobe a web interface na próxima porta livre e a leitura pegaria o
# túnel do outro processo.
wait_for_tunnel() {
  local deadline=$((SECONDS + 30))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if grep -q 'msg="started tunnel"' "$NGROK_LOG" 2>/dev/null; then
      return 0
    fi
    if grep -qE 'lvl=(error|crit)|msg="session closing"' "$NGROK_LOG" 2>/dev/null; then
      return 1
    fi
    kill -0 "$NGROK_PID" 2>/dev/null || return 1
    sleep 0.25
  done
  return 1
}

cleanup() {
  local pid
  for pid in "$NGROK_PID" "$SERVER_PID"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT INT TERM

# 127.0.0.1, não 0.0.0.0: a única porta de entrada é o túnel.
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$WEB_DIR" \
  >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

curl -fsS -o /dev/null \
  --retry 20 --retry-connrefused --retry-delay 1 \
  "http://127.0.0.1:$PORT/" 2>/dev/null \
  || die "o servidor estático não respondeu em http://127.0.0.1:$PORT/ (veja $SERVER_LOG)"

ngrok http "127.0.0.1:$PORT" --url="https://$DOMAIN" --log "$NGROK_LOG" >/dev/null 2>&1 &
NGROK_PID=$!

if ! wait_for_tunnel; then
  echo "--- últimas linhas do ngrok ($NGROK_LOG) ---" >&2
  tail -n 20 "$NGROK_LOG" >&2 || true
  die "o túnel não subiu para o domínio $DOMAIN (dono já usando o domínio? authtoken inválido?)."
fi

# Prova real da URL pública, não só do processo: o edge do ngrok devolve 404
# enquanto o túnel não está registrado. O header pula o aviso do free tier.
STATUS="$(curl -sS -o /dev/null -w '%{http_code}' \
  --retry 10 --retry-all-errors --retry-delay 1 \
  -H 'ngrok-skip-browser-warning: true' \
  "https://$DOMAIN/" 2>/dev/null || true)"

if [ "$STATUS" != "200" ]; then
  echo "--- últimas linhas do ngrok ($NGROK_LOG) ---" >&2
  tail -n 20 "$NGROK_LOG" >&2 || true
  die "https://$DOMAIN não respondeu 200 (obtido: ${STATUS:-sem resposta})."
fi

echo
echo "Build web....: $WEB_DIR"
echo "Servidor.....: http://127.0.0.1:$PORT ($SERVER_LOG)"
echo "Público......: https://$DOMAIN"
echo "PIDs.........: servidor $SERVER_PID · ngrok $NGROK_PID"
echo "Ctrl+C para parar (derruba servidor e túnel)."
echo

# Fica no ar até Ctrl+C; se o ngrok morrer sozinho, o script cai junto.
wait "$NGROK_PID"
