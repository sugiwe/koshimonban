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
    Tatsumaki/Sources/Models/TimeOfDay.swift \
    Tatsumaki/Sources/Models/WorkBlock.swift \
    Tatsumaki/Sources/Models/VideoEntry.swift \
    Tatsumaki/Sources/Models/AppSettings.swift \
    Tatsumaki/Sources/Models/BreakResult.swift \
    Tatsumaki/Sources/Scheduling/ScheduleGrid.swift \
    tests/ScheduleGridTests/main.swift

"$OUT/gridtest"
