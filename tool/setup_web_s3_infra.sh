#!/usr/bin/env bash
# Cria (uma vez) a infra do site web publicado: bucket privado + OAC + CloudFront.
#
# Modelo: o site do contact manager (S3 + CloudFront + OAC). Roda uma vez; repetir
# falha no create-bucket/create-origin-access-control/create-distribution, então
# este script NÃO é idempotente de propósito — ele imprime o que já existe quando
# dá erro, para você não recriar nada por engano.
#
# Uso:  tool/setup_web_s3_infra.sh
#
# O que ele NÃO faz: deploy do conteúdo (isso é tool/deploy_web_s3.sh) e domínio
# próprio (exigiria certificado ACM em us-east-1 + CNAME no DNS da zona).
set -euo pipefail

PROFILE="${PROFILE:-vit}"
REGION="${REGION:-sa-east-1}"
BUCKET="${BUCKET:-soniox-transcriptor-web-419242000325}"
NAME="soniox-transcriptor-web"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

aws_() { aws --profile "$PROFILE" --region "$REGION" "$@"; }

die() {
	echo "ERRO: $*" >&2
	exit 1
}

ACCOUNT=$(aws --profile "$PROFILE" sts get-caller-identity --query Account --output text)
echo "==> conta $ACCOUNT ($PROFILE) / região $REGION / bucket $BUCKET"

echo "==> bucket privado"
aws_ s3api create-bucket --bucket "$BUCKET" \
	--create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
aws_ s3api put-public-access-block --bucket "$BUCKET" \
	--public-access-block-configuration \
	'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
aws_ s3api put-bucket-encryption --bucket "$BUCKET" \
	--server-side-encryption-configuration \
	'{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "==> Origin Access Control"
OAC_ID=$(aws_ cloudfront create-origin-access-control \
	--origin-access-control-config \
	"Name=$NAME-oac,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
	--query 'OriginAccessControl.Id' --output text)
echo "    OAC: $OAC_ID"

echo "==> distribuição CloudFront"
CONFIG=$(mktemp)
trap 'rm -f "$CONFIG"' EXIT
sed -e "s/BUCKET/$BUCKET/; s/REGION/$REGION/; s/OAC_ID/$OAC_ID/; s/CALLER_REF/$NAME-$(date +%s)/" \
	tool/cloudfront-web-distribution.json >"$CONFIG"

DIST=$(aws_ cloudfront create-distribution --distribution-config "file://$CONFIG" \
	--query 'Distribution.{Id:Id,Domain:DomainName}' --output json)
# --output text de um map sai em ordem alfabética de chave (DomainName, Id), não
# na ordem em que você listou — por isso o jq, e não awk nos campos.
DIST_ID=$(echo "$DIST" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Id"])')
DIST_DOMAIN=$(echo "$DIST" | python3 -c 'import json,sys; print(json.load(sys.stdin)["DomainName"])')
echo "    distribuição: $DIST_ID -> https://$DIST_DOMAIN"

echo "==> bucket policy (só esta distribuição pode ler)"
POLICY=$(mktemp)
trap 'rm -f "$CONFIG" "$POLICY"' EXIT
cat >"$POLICY" <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "AllowCloudFrontReadOnly",
			"Effect": "Allow",
			"Principal": { "Service": "cloudfront.amazonaws.com" },
			"Action": "s3:GetObject",
			"Resource": "arn:aws:s3:::$BUCKET/*",
			"Condition": {
				"StringEquals": {
					"AWS:SourceArn": "arn:aws:cloudfront::$ACCOUNT:distribution/$DIST_ID"
				}
			}
		}
	]
}
EOF
aws_ s3api put-bucket-policy --bucket "$BUCKET" --policy "file://$POLICY"

echo
echo "Infra pronta. Cole estes valores em tool/deploy_web_s3.sh:"
echo "  BUCKET=$BUCKET"
echo "  DISTRIBUTION_ID=$DIST_ID"
echo "  URL=https://$DIST_DOMAIN"
echo
echo "Depois: tool/deploy_web_s3.sh (build + upload + invalidação)."
