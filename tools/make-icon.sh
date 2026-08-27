#!/bin/bash
# アプリアイコンを生成して Tatsumaki/Sources/Resources/AppIcon.icns に置く。
# デザインを変えたいときは make-icon.swift を編集してこれを実行する。
set -euo pipefail

cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

swiftc -O -o "$WORK/gen" tools/make-icon.swift -framework Cocoa
"$WORK/gen" "$WORK"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
cp "$WORK/icon_16.png"   "$ICONSET/icon_16x16.png"
cp "$WORK/icon_32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$WORK/icon_32.png"   "$ICONSET/icon_32x32.png"
cp "$WORK/icon_64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$WORK/icon_128.png"  "$ICONSET/icon_128x128.png"
cp "$WORK/icon_256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$WORK/icon_256.png"  "$ICONSET/icon_256x256.png"
cp "$WORK/icon_512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$WORK/icon_512.png"  "$ICONSET/icon_512x512.png"
cp "$WORK/icon_1024.png" "$ICONSET/icon_512x512@2x.png"

mkdir -p Tatsumaki/Sources/Resources
iconutil -c icns "$ICONSET" -o Tatsumaki/Sources/Resources/AppIcon.icns
echo "生成しました: Tatsumaki/Sources/Resources/AppIcon.icns"
