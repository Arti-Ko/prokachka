#!/usr/bin/env bash
# Собирает артефакты выпуска для Mac:
#   dist/Prokachka.dmg — установщик (перетащить в «Программы»),
#   dist/Prokachka.zip — то же приложение архивом.
# Использование: Scripts/package.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Prokachka.app"

"$ROOT/Scripts/build.sh"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

rm -f "$DIST/Prokachka.zip" "$DIST/Prokachka.dmg"

echo "==> архив"
ditto -c -k --keepParent "$APP" "$DIST/Prokachka.zip"

echo "==> установщик DMG"
ditto "$APP" "$STAGING/Прокачка.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Прокачка" -srcfolder "$STAGING" -ov -format UDZO "$DIST/Prokachka.dmg" >/dev/null

echo "готово: $DIST/Prokachka.dmg, $DIST/Prokachka.zip"
