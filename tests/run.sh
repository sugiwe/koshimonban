#!/bin/bash
# 発動判定（ScheduleGrid）の検証。
#
# このアプリは実時間で動くため、境界条件をアプリ上で確かめると1回30分かかる。
# 副作用のない計算部分だけを切り出して、ここで一気に確認する。
#
# Xcode は不要。swiftc だけで走る。
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

swiftc -O -o "$OUT/gridtest" \
    Koshimonban/Sources/Models/TimeOfDay.swift \
    Koshimonban/Sources/Models/WorkBlock.swift \
    Koshimonban/Sources/Models/VideoEntry.swift \
    Koshimonban/Sources/Models/AppSettings.swift \
    Koshimonban/Sources/Models/BreakResult.swift \
    Koshimonban/Sources/Models/SkipReason.swift \
    Koshimonban/Sources/Models/BreakRecord.swift \
    Koshimonban/Sources/Scheduling/ScheduleGrid.swift \
    Koshimonban/Sources/Video/YouTubeURL.swift \
    tests/ScheduleGridTests/main.swift

"$OUT/gridtest"
