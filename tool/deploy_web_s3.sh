#!/usr/bin/env bash
# Builda o app para web e publica no S3 atrás do CloudFront (URL pública).
#
# Mesmo modelo do contact manager web: bucket privado, CloudFront com OAC,
# cache por tipo de arquivo e invalidação no fim. A diferença é que o build do
# Flutter NÃO tem hash no nome dos arquivos (main.dart.js, flutter_bootstrap.js,
# assets/…), então nada aqui pode ser "immutable": o HTML e os JS do boot são
# sempre revalidados e assets/canvaskit têm cache curto. Se fossem cacheados por
# muito tempo, um deploy novo ficaria misturado com o build anterior no browser.
#
# Uso:
#   tool/deploy_web_s3.sh          build + upload + invalidar CloudFront
#   tool/deploy_web_s3.sh --url    só imprime a URL pública e o status HTTP
#
# Infra (bucket, OAC, distribuição) é criada uma única vez por
# tool/setup_web_s3_infra.sh.
set -euo pipefail

BUCKET="soniox-transcriptor-web-419242000325"
DISTRIBUTION_ID="E1COLUVKO80UG3"
PROFILE="vit"
REGION="sa-east-1"
MODE="deploy"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--url | -u)
		MODE="url"
		shift
		;;
	*)
		echo "argumento desconhecido: $1" >&2
		echo "uso: $0 [--url]" >&2
		exit 1
		;;
	esac
done

cd "$(dirname "${BASH_SOURCE[0]}")/.."

aws_() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

die() {
	echo "ERRO: $*" >&2
	exit 1
}

show_url() {
	local domain code
	domain=$(aws_ cloudfront get-distribution --id "$DISTRIBUTION_ID" \
		--query 'Distribution.DomainName' --output text)
	code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$domain/" || echo "000")
	echo "https://$domain  (HTTP $code)"
}

if [[ "$MODE" == "url" ]]; then
	show_url
	exit 0
fi

for bin in flutter aws curl; do
	command -v "$bin" >/dev/null 2>&1 || die "'$bin' não está no PATH."
done

echo "==> build web (sem CDN de canvaskit: tudo servido pelo próprio bucket)"
flutter pub get
flutter build web --release --no-web-resources-cdn --pwa-strategy=none

[ -f build/web/index.html ] || die "o build web não gerou build/web/index.html"

# Sem service worker: em vez de sumir com o arquivo, publica um worker que se
# AUTODESTRÓI. Sumir não funciona — o CloudFront responde 404 com index.html
# (content-type text/html), a checagem de update falha e o worker antigo
# continua servindo o bundle velho. Um worker válido que apaga caches,
# desregistra e recarrega os clientes mata o antigo na primeira navegação.
cat > build/web/flutter_service_worker.js <<'JS'
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
      await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach((c) => c.navigate(c.url));
    } catch (e) {
      await self.registration.unregister();
    }
  })());
});
JS

echo "==> upload (HTML e JS de boot: sempre revalidar)"
aws_ s3 sync build/web "s3://$BUCKET" --exclude "*" \
	--include "index.html" --include "manifest.json" --include "version.json" \
	--include "flutter.js" --include "flutter_bootstrap.js" \
	--include "flutter_service_worker.js" --include "main.dart.js" \
	--cache-control "public,max-age=0,must-revalidate" --only-show-errors

echo "==> upload (canvaskit: 1h)"
aws_ s3 sync build/web "s3://$BUCKET" --exclude "*" --include "canvaskit/*" \
	--cache-control "public,max-age=3600" --only-show-errors

echo "==> upload (assets, ícones: 5 min)"
aws_ s3 sync build/web "s3://$BUCKET" --exclude "*" \
	--include "assets/*" --include "icons/*" --include "favicon.png" \
	--cache-control "public,max-age=300" --only-show-errors

echo "==> upload (resto: sempre revalidar)"
aws_ s3 sync build/web "s3://$BUCKET" --exclude "*" \
	--cache-control "public,max-age=0,must-revalidate" --only-show-errors

# --size-only evita re-subir o que já está lá e apagar o cache-control definido
# acima; sobra só a remoção de chave órfã de um build anterior.
aws_ s3 sync build/web "s3://$BUCKET" --delete --size-only --only-show-errors

echo "==> invalidar CloudFront"
INVALIDATION_ID=$(aws_ cloudfront create-invalidation \
	--distribution-id "$DISTRIBUTION_ID" --paths "/*" \
	--query 'Invalidation.Id' --output text)

echo "==> aguardando invalidação $INVALIDATION_ID"
aws_ cloudfront wait invalidation-completed \
	--distribution-id "$DISTRIBUTION_ID" --id "$INVALIDATION_ID"

echo
echo "==> no ar:"
show_url
