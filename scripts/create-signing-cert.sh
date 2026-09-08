#!/bin/bash
# Cria UMA vez uma identidade de assinatura de código local e estável ("Norte
# Local"). Com ela, o app é assinado sempre com a mesma identidade, então a
# permissão de calendário (TCC) para de resetar a cada build — ao contrário da
# assinatura ad-hoc ("-"), cuja assinatura muda a cada compilação.
#
# Uso: ./scripts/create-signing-cert.sh   (roda uma vez; depois é só install-mac.sh)
set -euo pipefail

IDENTITY="Norte Local"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  echo "✓ Identidade '$IDENTITY' já existe. Nada a fazer."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = Norte Local
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# Chave + certificado autoassinado válido por 10 anos, marcado para "code signing".
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -days 3650 -config "$TMP/openssl.cnf" >/dev/null 2>&1

# PKCS12 com senha não-vazia. `-legacy` (OpenSSL 3) gera MAC/algoritmos que o
# Security framework do macOS aceita; em LibreSSL o flag não existe, então cai
# no formato padrão (que já é compatível).
P12PASS="norte"
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$IDENTITY" -out "$TMP/id.p12" -passout "pass:$P12PASS" -legacy >/dev/null 2>&1 \
  || openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
       -name "$IDENTITY" -out "$TMP/id.p12" -passout "pass:$P12PASS" >/dev/null 2>&1

# Importa no login keychain e libera o /usr/bin/codesign a usar a chave sem
# pedir senha toda hora (-A). Não precisa de trust do sistema para assinar local.
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$P12PASS" -T /usr/bin/codesign -A >/dev/null

echo "✓ Criada a identidade de assinatura '$IDENTITY'."
echo "  Agora rode ./scripts/install-mac.sh — a partir daqui a permissão de"
echo "  calendário só é pedida UMA vez e não reseta mais a cada build."
