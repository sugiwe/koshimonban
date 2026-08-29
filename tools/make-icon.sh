#!/bin/bash
# アプリアイコンを生成して Koshimonban/Sources/Resources/AppIcon.icns に置く。
# 絵を変えたいときは tools/icon-source.png を差し替えてこれを実行する。
#
# 元画像は正方形・中央配置であればよい。角丸の外側が透明でも黒く塗られていても、
# make-icon.swift 側で絵の本体を切り出して squircle に収める。
set -euo pipefail

cd "$(dirname "$0")/.."
SOURCE="${1:-tools/icon-source.png}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$SOURCE" ]; then
    echo "元画像が見つかりません: $SOURCE"
    exit 1
fi

swiftc -O -o "$WORK/gen" tools/make-icon.swift -framework Cocoa
"$WORK/gen" "$SOURCE" "$WORK"

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

mkdir -p Koshimonban/Sources/Resources
iconutil -c icns "$ICONSET" -o Koshimonban/Sources/Resources/AppIcon.icns
echo "生成しました: Koshimonban/Sources/Resources/AppIcon.icns"
