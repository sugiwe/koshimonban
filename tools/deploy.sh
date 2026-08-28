#!/bin/bash
# ビルドして /Applications に入れ直し、起動し直す。
#
# LaunchAgent の plist にはアプリの実行ファイルのパスが直接書き込まれるため、
# アプリの置き場所は固定しておきたい。/Applications に置いておけば、
# コードを直しても自動起動の登録をやり直す必要がない。
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Koshimonban"
BUNDLE_ID="net.sugiwe.koshimonban"
DESTINATION="/Applications/${APP_NAME}.app"

echo "==> ビルド中..."
xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" \
    -configuration Debug build > /tmp/koshimonban-build.log 2>&1 || {
    echo "ビルドに失敗しました。詳細:"
    grep -E "error:" /tmp/koshimonban-build.log | head -20
    exit 1
}

BUILT=$(xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Debug \
    -showBuildSettings 2>/dev/null | grep -m1 " BUILT_PRODUCTS_DIR" | awk '{print $3}')/${APP_NAME}.app

if [ ! -d "$BUILT" ]; then
    echo "ビルド結果が見つかりません: $BUILT"
    exit 1
fi

echo "==> 動いているアプリを終了..."
pkill -x "${APP_NAME}" 2>/dev/null || true

# 置き換え先が本当に自分のアプリか確かめてから消す
if [ -d "$DESTINATION" ]; then
    EXISTING_ID=$(defaults read "${DESTINATION}/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "")
    if [ "$EXISTING_ID" != "$BUNDLE_ID" ]; then
        echo "${DESTINATION} は Koshimonban ではないようです（${EXISTING_ID}）。中断します。"
        exit 1
    fi
    rm -rf "$DESTINATION"
fi

echo "==> /Applications にコピー..."
cp -R "$BUILT" "$DESTINATION"

echo "==> 起動..."
open "$DESTINATION"

echo ""
echo "完了しました: $DESTINATION"
echo "自動起動の登録はパスが変わらないので、やり直す必要はありません。"
