#!/usr/bin/env bash
# Собирает Прокачку: релизный бинарник, Info.plist, иконка и подпись.
# Использование: Scripts/build.sh [--install]
#   --install  кладёт в /Applications и перезапускает приложение.
#
# Подпись: сертификат «Apple Development», если он есть в связке ключей, иначе ad-hoc.
# Свой сертификат: PROKACHKA_SIGN_IDENTITY="…" Scripts/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Prokachka"
DISPLAY_NAME="Прокачка"
BUNDLE_ID="org.sleepycoffee.prokachka"
VERSION="$(tr -d '[:space:]' < "$ROOT/../VERSION")"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

# Глобальный git этой машины (safe.bareRepository=explicit) ломает SwiftPM.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all

cd "$ROOT"

echo "==> $DISPLAY_NAME $VERSION ($BUILD_NUMBER)"
swift build -c release
BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
[ -x "$BINARY" ] || { echo "не найден бинарник $BINARY"; exit 1; }

echo "==> собираю бандл"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"

ICON_KEY=""
if [ -f "$ROOT/Assets/AppIcon.icns" ]; then
    cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleDevelopmentRegion</key><string>ru</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    $ICON_KEY
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Прокачка</string>
</dict>
</plist>
PLIST

IDENTITY="${PROKACHKA_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development/ { print $2; exit }')}"
echo "==> подписываю: ${IDENTITY:-ad-hoc}"
codesign --force --sign "${IDENTITY:--}" --timestamp=none "$APP" >/dev/null

if [ "${1:-}" != "--install" ]; then
    echo "готово: $APP"
    exit 0
fi

echo "==> ставлю в /Applications"
pkill -x "$APP_NAME" 2>/dev/null && sleep 0.5 || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP" "/Applications/$APP_NAME.app"
open "/Applications/$APP_NAME.app"
echo "готово: /Applications/$APP_NAME.app"
