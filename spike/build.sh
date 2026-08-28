#!/bin/bash
# Xcode なしで .app バンドルを組み立てる検証用ビルドスクリプト。
# 本実装では Xcode プロジェクトを使うので、これはスパイク専用。
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="KoshimonbanSpike"
BUNDLE="build/${APP_NAME}.app"

rm -rf build
mkdir -p "${BUNDLE}/Contents/MacOS"

cat > "${BUNDLE}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>KoshimonbanSpike</string>
    <key>CFBundleExecutable</key>      <string>KoshimonbanSpike</string>
    <key>CFBundleIdentifier</key>      <string>net.sugiwe.koshimonban.spike</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>0.1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

swiftc -O \
    -target arm64-apple-macos14.0 \
    -framework Cocoa \
    -o "${BUNDLE}/Contents/MacOS/${APP_NAME}" \
    main.swift

# 署名なしだと OS に弾かれることがあるので ad-hoc 署名しておく
codesign --force --sign - "${BUNDLE}" 2>/dev/null || echo "（ad-hoc 署名をスキップしました）"

echo "ビルド完了: ${BUNDLE}"
