#!/bin/bash
# Instala o Norte no iPhone conectado (cabo ou Wi-Fi).
# Rode a cada 7 dias — limite da conta Apple gratuita.
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf '\033[1;36m%s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }

command -v xcodegen >/dev/null || fail "xcodegen não encontrado. Instale com: brew install xcodegen"

say "→ Gerando o projeto Xcode..."
xcodegen generate -q

say "→ Procurando seu iPhone..."
DEVICE_JSON=$(mktemp)
xcrun devicectl list devices --json-output "$DEVICE_JSON" >/dev/null
UDID=$(/usr/bin/python3 - "$DEVICE_JSON" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for d in data.get("result", {}).get("devices", []):
    props = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    if props.get("deviceType") == "iPhone" and conn.get("tunnelState") != "unavailable":
        print(d.get("hardwareProperties", {}).get("udid") or d.get("identifier", ""))
        break
PY
)
[ -n "$UDID" ] || fail "Nenhum iPhone encontrado. Conecte pelo cabo, desbloqueie a tela e confie neste Mac."
say "   iPhone encontrado: $UDID"

# Time de assinatura: usa NORTE_TEAM_ID se definido; senão detecta o
# certificado "Apple Development" criado quando você loga seu Apple ID no Xcode.
TEAM="${NORTE_TEAM_ID:-}"
if [ -z "$TEAM" ]; then
  TEAM=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o 'Apple Development[^"]*([A-Z0-9]\{10\})' \
    | head -1 | grep -o '[A-Z0-9]\{10\}' | tail -1 || true)
fi
[ -n "$TEAM" ] || fail "Nenhum certificado de desenvolvimento encontrado.
Abra o Xcode → Settings → Accounts, entre com seu Apple ID,
depois abra Norte.xcodeproj, selecione o target Norte-iOS → Signing
e escolha seu time pessoal. Rode este script de novo em seguida."

say "→ Compilando e assinando (team $TEAM)..."
xcodebuild -project Norte.xcodeproj \
  -scheme Norte-iOS \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath build \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM" \
  build | grep -E "error|warning: Signing|SUCCEEDED|FAILED" || true

APP="build/Build/Products/Debug-iphoneos/Norte.app"
[ -d "$APP" ] || fail "Build falhou. Rode sem filtro para ver o erro:
  xcodebuild -project Norte.xcodeproj -scheme Norte-iOS -destination \"id=$UDID\" -allowProvisioningUpdates DEVELOPMENT_TEAM=$TEAM build"

say "→ Instalando no iPhone..."
xcrun devicectl device install app --device "$UDID" "$APP"

say "✓ Pronto! Válido por 7 dias. Se for a primeira vez, autorize o app em:
  iPhone → Ajustes → Geral → VPN e Gerenciamento de Dispositivo."
