import Foundation

var failures = 0
func check(_ label: String, _ actual: String, _ expected: String) {
    if actual == expected {
        print("  OK   \(label)")
    } else {
        print("  FAIL \(label)\n         期待: \(expected)\n         実際: \(actual)")
        failures += 1
    }
}

func settings(blocks: [WorkBlock], interval: Int = 30, breakSec: Int = 180,
              debug: Bool = false, ignoreBlocks: Bool = false) -> AppSettings {
    var s = AppSettings.default
    s.workBlocks = blocks
    s.intervalMinutes = interval
    s.breakSeconds = breakSec
    s.debugMode = debug
    s.debugIgnoreWorkBlocks = ignoreBlocks
    return s
}

func block(_ start: String, _ end: String, _ weekdays: [Int] = [1,2,3,4,5,6,7]) -> WorkBlock {
    WorkBlock(start: TimeOfDay(string: start)!, end: TimeOfDay(string: end)!, weekdays: weekdays)
}

func times(_ s: AppSettings, weekday: Int = 1) -> String {
    ScheduleGrid.slots(settings: s, weekday: weekday)
        .map { ScheduleGrid.timeString(fromSeconds: $0.at) }
        .joined(separator: " ")
}

print("\n=== 固定グリッド ===")
check("10:00–12:00 / 30分 / 休憩3分",
      times(settings(blocks: [block("10:00", "12:00")])),
      "10:30 11:00 11:30")

check("時間帯の終端では発動しない（12:00 が無い）",
      times(settings(blocks: [block("10:00", "12:00")])).contains("12:00") ? "含む" : "含まない",
      "含まない")

check("2つの時間帯 10:00–12:00 と 14:00–17:00",
      times(settings(blocks: [block("10:00", "12:00"), block("14:00", "17:00")])),
      "10:30 11:00 11:30 14:30 15:00 15:30 16:00 16:30")

print("\n=== 境界条件: 休憩が時間帯に収まるか ===")
check("10:00–10:33 は休憩3分がちょうど収まる",
      times(settings(blocks: [block("10:00", "10:33")])),
      "10:30")
check("10:00–10:32 は収まらないので発動なし",
      times(settings(blocks: [block("10:00", "10:32")])),
      "")
// 仕様書の「11:58 に発動しない」を実際に踏む条件。
// 間隔59分だと 10:59 の次が 11:58 になるが、休憩終了が 12:01 で時間帯をはみ出すため落ちる。
check("11:58 は休憩がはみ出すので発動しない（10:00–12:00 / 間隔59分）",
      times(settings(blocks: [block("10:00", "12:00")], interval: 59)),
      "10:59")
check("休憩を1分に縮めれば 11:58 も発動する",
      times(settings(blocks: [block("10:00", "12:00")], interval: 59, breakSec: 60)),
      "10:59 11:58")

print("\n=== マージ ===")
check("重なる時間帯はマージし、起点はマージ後の開始時刻",
      times(settings(blocks: [block("10:00", "12:00"), block("11:00", "13:00")])),
      "10:30 11:00 11:30 12:00 12:30")
check("接しているだけの時間帯はマージしない（それぞれ独立したグリッド）",
      times(settings(blocks: [block("10:00", "12:00"), block("12:00", "13:00")])),
      "10:30 11:00 11:30 12:30")
check("曜日が違えばマージしない",
      times(settings(blocks: [block("10:00", "12:00", [1]), block("11:00", "13:00", [2])]), weekday: 1),
      "10:30 11:00 11:30")

print("\n=== 曜日 ===")
check("月曜のみ有効な時間帯を火曜に問い合わせる",
      times(settings(blocks: [block("10:00", "12:00", [1])]), weekday: 2),
      "")
var weekdayMapping: [String] = []
let calendar = Calendar.current
var probe = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24))!  // 月曜
for _ in 0..<7 {
    weekdayMapping.append(String(ScheduleGrid.weekdayIndex(for: probe, calendar: calendar)))
    probe = calendar.date(byAdding: .day, value: 1, to: probe)!
}
check("2026-08-24(月) から7日間の曜日番号", weekdayMapping.joined(separator: ","), "1,2,3,4,5,6,7")

print("\n=== デバッグモード ===")
let debugSettings = settings(blocks: [block("10:00", "12:00")], interval: 30, breakSec: 10, debug: true)
let debugSlots = ScheduleGrid.slots(settings: debugSettings, weekday: 1)
check("間隔30が「秒」として扱われる（先頭3件）",
      debugSlots.prefix(3).map { ScheduleGrid.preciseTimeString(fromSeconds: $0.at) }.joined(separator: " "),
      "10:00:30 10:01:00 10:01:30")
let ignoreSettings = settings(blocks: [], interval: 30, breakSec: 10, debug: true, ignoreBlocks: true)
check("作業時間帯を無視すると時間帯0件でも発動予定が立つ",
      ScheduleGrid.slots(settings: ignoreSettings, weekday: 1).isEmpty ? "予定なし" : "予定あり",
      "予定あり")

print("\n=== 追いつき判定 (canFire) ===")
let catchUpSlot = ScheduleGrid.slots(settings: settings(blocks: [block("10:00", "12:00")]), weekday: 1)[0]
check("予定時刻ちょうど（10:30）は発動できる",
      ScheduleGrid.canFire(slot: catchUpSlot, atSeconds: 10*3600+30*60, breakSeconds: 180) ? "可" : "不可", "可")
check("11:30 まで遅れても、休憩が時間帯に収まるので追いつける",
      ScheduleGrid.canFire(slot: catchUpSlot, atSeconds: 11*3600+30*60, breakSeconds: 180) ? "可" : "不可", "可")
check("11:58 まで遅れると休憩が収まらないので追いつけない",
      ScheduleGrid.canFire(slot: catchUpSlot, atSeconds: 11*3600+58*60, breakSeconds: 180) ? "可" : "不可", "不可")
check("時間帯が終わったあと（12:30）は追いつけない",
      ScheduleGrid.canFire(slot: catchUpSlot, atSeconds: 12*3600+30*60, breakSeconds: 180) ? "可" : "不可", "不可")

print("\n=== 異常な設定 ===")
check("終了が開始より前の時間帯は無視される",
      times(settings(blocks: [block("14:00", "10:00")])), "")
check("間隔0では発動予定を作らない",
      times(settings(blocks: [block("10:00", "12:00")], interval: 0)), "")

print("\n=== YouTube の URL 解析 ===")
func checkID(_ label: String, _ input: String, _ expected: String?) {
    let actual = YouTubeURL.videoID(from: input)
    check(label, actual ?? "(nil)", expected ?? "(nil)")
}
checkID("標準の watch URL", "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("追加パラメータ付き", "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PLxxx", "dQw4w9WgXcQ")
checkID("パラメータの順序が違う", "https://www.youtube.com/watch?t=42s&v=dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("短縮 URL", "https://youtu.be/dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("短縮 URL + パラメータ", "https://youtu.be/dQw4w9WgXcQ?t=42", "dQw4w9WgXcQ")
checkID("埋め込み URL", "https://www.youtube.com/embed/dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("nocookie の埋め込み URL", "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("Shorts", "https://www.youtube.com/shorts/dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("ライブ", "https://www.youtube.com/live/dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("m. のモバイル URL", "https://m.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("スキームなし", "www.youtube.com/watch?v=dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("前後の空白", "  https://youtu.be/dQw4w9WgXcQ  ", "dQw4w9WgXcQ")
checkID("ID を直接貼った場合", "dQw4w9WgXcQ", "dQw4w9WgXcQ")
checkID("YouTube 以外の URL は拒否", "https://vimeo.com/12345", nil)
checkID("空文字は拒否", "", nil)
checkID("v パラメータのない YouTube URL は拒否", "https://www.youtube.com/feed/subscriptions", nil)
checkID("不正な文字を含む ID は拒否", "https://youtu.be/abc$def", nil)

print("")
if failures == 0 {
    print("すべて期待どおりです（\(failures) 件の失敗）")
} else {
    print("\(failures) 件が期待と違います")
    exit(1)
}
