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

func settings(blocks: [LegacyWorkBlock], interval: Int = 30, breakSec: Int = 180,
              debug: Bool = false, ignoreBlocks: Bool = false) -> AppSettings {
    var s = AppSettings.default
    // テストは「時間帯 + 曜日」で書いた方が読みやすいので、移行の仕組みを通して組み立てる
    s.schedule = WeekSchedule.migrating(from: blocks)
    s.intervalMinutes = interval
    s.breakSeconds = breakSec
    s.debugMode = debug
    s.debugIgnoreWorkBlocks = ignoreBlocks
    return s
}

func block(_ start: String, _ end: String, _ weekdays: [Int] = [1,2,3,4,5,6,7]) -> LegacyWorkBlock {
    LegacyWorkBlock(start: TimeOfDay(string: start)!, end: TimeOfDay(string: end)!, weekdays: weekdays)
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

print("\n=== 記録の JSON 形式 ===")
let sampleRecord = BreakRecord(
    scheduledAt: TimeOfDay(string: "11:00")!,
    firedAt: TimeOfDay(string: "11:00")!,
    result: .skipped,
    skipReason: .meeting,
    shownSeconds: 7,
    videoTitle: "肩と腰のストレッチ"
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
let encoded = String(data: try! encoder.encode(["2026-08-27": [sampleRecord]]), encoding: .utf8)!
check("仕様書のフォーマットで書き出される", encoded,
      #"{"2026-08-27":[{"firedAt":"11:00","result":"skipped","scheduledAt":"11:00","shownSeconds":7,"skipReason":"meeting","videoTitle":"肩と腰のストレッチ"}]}"#)

let roundTripped = try! JSONDecoder().decode([String: [BreakRecord]].self, from: encoded.data(using: .utf8)!)
check("読み戻せる", roundTripped["2026-08-27"]?.first?.skipReason?.rawValue ?? "(nil)", "meeting")

// 手で編集されてキーが欠けても読めること
let partial = #"{"2026-08-27":[{"scheduledAt":"10:30","result":"completed"}]}"#
let partialDecoded = try! JSONDecoder().decode([String: [BreakRecord]].self, from: partial.data(using: .utf8)!)
check("キーが欠けていても既定値で読める",
      "\(partialDecoded["2026-08-27"]?.first?.firedAt.displayString ?? "(nil)") / \(partialDecoded["2026-08-27"]?.first?.shownSeconds ?? -1)",
      "10:30 / 0")

print("\n=== 達成率の数え方 ===")
check("完了は達成に数える", BreakResult.completed.countsAsAchieved ? "数える" : "数えない", "数える")
check("短縮も達成に数える（立ち上がってはいる）", BreakResult.short.countsAsAchieved ? "数える" : "数えない", "数える")
check("スキップは達成に数えないが、分母には入れる",
      "\(BreakResult.skipped.countsAsAchieved) / \(BreakResult.skipped.countsInTotal)", "false / true")
check("取りこぼしは分母にも入れない（本人の意思ではないため）",
      "\(BreakResult.missed.countsAsAchieved) / \(BreakResult.missed.countsInTotal)", "false / false")
check("一時停止も分母に入れない",
      "\(BreakResult.paused.countsAsAchieved) / \(BreakResult.paused.countsInTotal)", "false / false")

print("\n=== タイル（30分刻み）と範囲の相互変換 ===")
func slotsOf(_ ranges: [(String, String)]) -> [Int] {
    Set(ranges.map { TimeRange(start: TimeOfDay(string: $0.0)!, end: TimeOfDay(string: $0.1)!) }
        .flatMap { $0.slotIndices }).sorted()
}
func rangesOf(_ slots: [Int]) -> String {
    TimeRange.ranges(fromSlots: Set(slots)).map(\.displayString).joined(separator: " ")
}
check("10:00–12:00 は 20〜23 のタイル", slotsOf([("10:00","12:00")]).map(String.init).joined(separator: ","), "20,21,22,23")
check("連続したタイルは1つの範囲にまとまる", rangesOf([20,21,22,23]), "10:00–12:00")
check("離れたタイルは別々の範囲になる", rangesOf([20,21,28,29]), "10:00–11:00 14:00–15:00")
check("1枚だけでも範囲になる", rangesOf([20]), "10:00–10:30")
check("最後のタイルは 24:00 で終わる", rangesOf([47]), "23:30–24:00")
check("範囲→タイル→範囲で元に戻る",
      rangesOf(slotsOf([("06:00","12:00"), ("13:00","18:00")])),
      "06:00–12:00 13:00–18:00")
check("空なら範囲も空", rangesOf([]), "")

print("\n=== v1 からの移行 ===")
let legacyJSON = """
{"version":1,"intervalMinutes":30,"breakSeconds":180,
 "workBlocks":[{"id":"11111111-1111-1111-1111-111111111111","start":"10:00","end":"12:00","weekdays":[1,3]},
               {"id":"22222222-2222-2222-2222-222222222222","start":"14:00","end":"17:00","weekdays":[1]}]}
"""
let migrated = try! JSONDecoder().decode(AppSettings.self, from: legacyJSON.data(using: .utf8)!)
check("月曜には2つの時間帯が移る",
      migrated.schedule[.mon].map(\.displayString).joined(separator: " "), "10:00–12:00 14:00–17:00")
check("水曜には1つだけ移る",
      migrated.schedule[.wed].map(\.displayString).joined(separator: " "), "10:00–12:00")
check("指定の無い火曜は空", migrated.schedule[.tue].isEmpty ? "空" : "空でない", "空")
check("v1 形式だと判定できる",
      AppSettings.isLegacyFormat(legacyJSON.data(using: .utf8)!) ? "v1" : "v1ではない", "v1")

let encoder2 = JSONEncoder()
encoder2.outputFormatting = [.sortedKeys]
let reEncoded = String(data: try! encoder2.encode(migrated.schedule), encoding: .utf8)!
check("書き出しは曜日名をキーにした形になる",
      reEncoded.contains("\"mon\":[{\"end\":\"12:00\",\"start\":\"10:00\"}") ? "はい" : "いいえ", "はい")
check("移行後は v1 形式と判定されない",
      AppSettings.isLegacyFormat(try! JSONEncoder().encode(migrated)) ? "v1" : "v1ではない", "v1ではない")

print("\n=== 発動の判定（仕様書 3.2 の境界条件）===")
let day = settings(blocks: [block("10:00", "12:00")])          // 10:30 11:00 11:30
let daySlots = ScheduleGrid.slots(settings: day, weekday: 1)
func at(_ time: String) -> Int { TimeOfDay(string: time)!.minutesFromMidnight * 60 }
func decide(_ now: String, resolved: [String] = [], paused: Bool = false,
            overlay: Bool = false, present: Bool = true, breakSec: Int = 180) -> String {
    let context = ScheduleGrid.Context(
        nowSeconds: at(now), resolved: Set(resolved.map(at)), isPaused: paused,
        isOverlayVisible: overlay, isUserPresent: present, breakSeconds: breakSec)
    let decisions = ScheduleGrid.decide(slots: daySlots, context: context)
    guard !decisions.isEmpty else { return "なし" }
    return decisions.map { decision in
        switch decision {
        case .fire(let slot): "発動:\(ScheduleGrid.timeString(fromSeconds: slot.at))"
        case .resolve(let slot, let result, _):
            "\(result.rawValue):\(ScheduleGrid.timeString(fromSeconds: slot.at))"
        }
    }.joined(separator: " ")
}

check("予定時刻ちょうどなら発動する", decide("10:30"), "発動:10:30")
check("予定時刻の前なら何もしない", decide("10:29"), "なし")
check("決着済みなら何もしない", decide("10:30", resolved: ["10:30"]), "なし")
check("たまっている場合、古い分は取りこぼし、直近だけ発動する",
      decide("11:30"), "missed:10:30 missed:11:00 発動:11:30")
check("一時停止中は発動せず、一時停止として決着する",
      decide("10:30", paused: true), "paused:10:30")
check("一時停止中でも、たまった古い分は取りこぼしになる",
      decide("11:30", paused: true), "missed:10:30 missed:11:00 paused:11:30")
check("オーバーレイ表示中は二重に出さない（決着もさせない）",
      decide("10:30", overlay: true), "なし")
check("不在中（ロック・ユーザー切り替え）は発動しない",
      decide("10:30", present: false), "なし")
check("不在のまま作業時間帯が終われば取りこぼしになる",
      decide("11:58", resolved: ["10:30", "11:00"], present: false), "missed:11:30")
check("在席していても、追いつく前に時間帯が終われば取りこぼし",
      decide("11:58", resolved: ["10:30", "11:00"]), "missed:11:30")
check("時間帯の途中なら遅れても追いつける",
      decide("11:00", resolved: ["10:30", "11:00"]), "なし")
check("休憩が長いと、追いつける余地が早く尽きる",
      decide("11:50", resolved: ["10:30", "11:00"], breakSec: 900), "missed:11:30")

print("\n=== 設定値の上限（手で編集された settings.json 対策）===")
let insane = """
{"version":2,"intervalMinutes":999999999999999999,"breakSeconds":-5,
 "preNotifyMinutes":9999,"skipUnlockSeconds":-1,"gridStartHour":99,"gridEndHour":-3,
 "schedule":{"mon":[{"start":"10:00","end":"12:00"}]}}
"""
let clamped = try! JSONDecoder().decode(AppSettings.self, from: insane.data(using: .utf8)!)
check("巨大な間隔は上限に丸められる", "\(clamped.intervalMinutes)", "\(24 * 60)")
check("負の休憩は下限に丸められる", "\(clamped.breakSeconds)", "1")
check("予告も範囲に収まる", "\(clamped.preNotifyMinutes)", "60")
check("スキップ解禁も範囲に収まる", "\(clamped.skipUnlockSeconds)", "0")
check("表示範囲も範囲に収まる", "\(clamped.gridStartHour)/\(clamped.gridEndHour)", "24/0")
// 丸めたあとに掛け算してもあふれない = 起動時クラッシュのループにならない
check("丸めた値なら秒への換算があふれない",
      "\(clamped.effectiveIntervalSeconds)", "\(24 * 60 * 60)")

print("\n=== 設定の妥当性チェック ===")
func errorsOf(_ mutate: (inout AppSettings) -> Void) -> String {
    var s = AppSettings.default
    mutate(&s)
    return s.validationErrors.isEmpty ? "問題なし" : "問題あり"
}
check("既定値は問題なし", errorsOf { _ in }, "問題なし")
check("時間帯が空なら問題あり", errorsOf { $0.schedule = WeekSchedule() }, "問題あり")
check("休憩が間隔より長ければ問題あり",
      errorsOf { $0.intervalMinutes = 30; $0.breakSeconds = 3600 }, "問題あり")
check("デバッグモードでも同じ基準で判定される（間隔30秒・休憩180秒）",
      errorsOf { $0.debugMode = true; $0.intervalMinutes = 30; $0.breakSeconds = 180 }, "問題あり")

print("")
if failures == 0 {
    print("すべて期待どおりです（\(failures) 件の失敗）")
} else {
    print("\(failures) 件が期待と違います")
    exit(1)
}
