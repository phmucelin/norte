#!/bin/bash
# Compila o Norte em RELEASE e instala em /Applications.
# Release embute o código do widget direto no appex (sem .debug.dylib), o que
# é essencial para o macOS reconhecer todos os widgets fora do Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

say() { printf '\033[1;36m%s\033[0m\n' "$*"; }

say "→ Gerando o projeto e compilando (Release)..."
xcodegen generate -q
xcodebuild -project Norte.xcodeproj -scheme Norte-macOS -configuration Release \
  -derivedDataPath build build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" || true
APP="build/Build/Products/Release/Norte.app"
[ -d "$APP" ] || { echo "Build Release falhou."; exit 1; }

say "→ Encerrando o app e removendo TODAS as cópias antigas..."
osascript -e 'tell application "Norte" to quit' 2>/dev/null || true
pkill -x Norte 2>/dev/null || true
# desregistra e remove cópias em DerivedData padrão e builds Debug
for OLD in "$HOME"/Library/Developer/Xcode/DerivedData/Norte-*/Build/Products/*/Norte.app \
           build/Build/Products/Debug/Norte.app; do
  [ -e "$OLD" ] || continue
  "$LSREGISTER" -u "$OLD" 2>/dev/null || true
done
rm -rf build/Build/Products/Debug/Norte.app 2>/dev/null || true

DEST="/Applications/Norte.app"
if ! (rm -rf "$DEST" 2>/dev/null && cp -R "$APP" "$DEST" 2>/dev/null); then
  DEST="$HOME/Applications/Norte.app"
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
fi
say "→ Instalado em $DEST"

say "→ Registrando e recarregando os widgets..."
"$LSREGISTER" -f "$DEST"
killall chronod 2>/dev/null || true
killall WidgetKitExtension 2>/dev/null || true

open "$DEST"
say "✓ Pronto. Abra 'Editar Widgets' → Norte: Minha semana, Meu dia e Tarefas a vencer."
