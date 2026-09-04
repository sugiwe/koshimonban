import Foundation

/// 発動時刻の計算。副作用を持たない純粋な計算だけをここに置く。
///
/// 発動時刻は「前回の休憩終了から N分後」ではなく
/// **各作業時間帯の開始時刻を起点とした固定グリッド** で決める。
/// スキップしてもグリッドはズレない。体がリズムを覚えられるようにするため。
enum ScheduleGrid {

    /// 1回の発動予定。すべて「その日の 0:00 からの経過秒」で表す。
    struct Slot: Equatable, Hashable {
        /// 発動予定時刻
        var at: Int
        /// この発動が属する作業時間帯
        var blockStart: Int
        var blockEnd: Int
    }

    static let secondsPerDay = 24 * 60 * 60

    // MARK: 曜日

    /// Calendar の weekday（1=日曜…7=土曜）を、設定ファイルの表記（1=月曜…7=日曜）に直す。
    static func weekdayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        let calendarWeekday = calendar.component(.weekday, from: date)
        return ((calendarWeekday + 5) % 7) + 1
    }

    /// その日の 0:00 からの経過秒
    static func secondsFromMidnight(for date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
    }

    // MARK: 作業時間帯

    /// 指定の曜日に有効な作業時間帯を、重なりをマージして返す。
    ///
    /// マージは「同じ曜日どうし」でのみ行う。接しているだけ（12:00 終わり と 12:00 始まり）は
    /// マージしない。別の時間帯として、それぞれの開始時刻を起点にグリッドを引く。
    static func mergedBlocks(settings: AppSettings, weekday: Int) -> [(start: Int, end: Int)] {
        if settings.debugMode && settings.debugIgnoreWorkBlocks {
            return [(start: 0, end: secondsPerDay)]
        }

        let ranges = settings.schedule[index: weekday]
            .filter { $0.isValid }
            .map { (start: $0.start.minutesFromMidnight * 60,
                    end:   $0.end.minutesFromMidnight * 60) }
            .sorted { $0.start < $1.start }

        var merged: [(start: Int, end: Int)] = []
        for range in ranges {
            if var last = merged.last, range.start < last.end {
                last.end = max(last.end, range.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    // MARK: グリッド

    /// その日の発動予定をすべて返す（昇順）。
    ///
    /// 起点は作業時間帯の開始時刻。開始時刻そのものでは発動しない（k は 1 から）。
    /// 休憩の終わりが時間帯をはみ出す発動は作らない。
    static func slots(settings: AppSettings, date: Date, calendar: Calendar = .current) -> [Slot] {
        let weekday = weekdayIndex(for: date, calendar: calendar)
        return slots(settings: settings, weekday: weekday)
    }

    static func slots(settings: AppSettings, weekday: Int) -> [Slot] {
        let interval = settings.effectiveIntervalSeconds
        let breakSeconds = settings.breakSeconds
        guard interval > 0, breakSeconds > 0 else { return [] }

        var result: [Slot] = []
        for block in mergedBlocks(settings: settings, weekday: weekday) {
            var k = 1
            while true {
                let at = block.start + k * interval
                // 休憩が時間帯に収まらなくなったら、そこで打ち切る。
                // 「発動時刻の残り時間が休憩の長さ未満なら発動しない」も同じ条件で表現できる。
                guard at + breakSeconds <= block.end else { break }
                result.append(Slot(at: at, blockStart: block.start, blockEnd: block.end))
                k += 1
                // 設定が壊れている場合の暴走よけ
                if k > 100_000 { break }
            }
        }
        return result.sorted { $0.at < $1.at }
    }

    /// いま（secondsFromMidnight）から見て次に来る発動予定。無ければ nil。
    static func nextSlot(after seconds: Int, settings: AppSettings, date: Date,
                         calendar: Calendar = .current) -> Slot? {
        slots(settings: settings, date: date, calendar: calendar)
            .first { $0.at > seconds }
    }

    /// この時刻に発動を始めても、休憩が作業時間帯に収まるか。
    ///
    /// スリープやロックからの復帰で予定時刻を過ぎてから発動する場合の判定に使う。
    /// 予定時刻ちょうどに発動する場合も同じ条件になるので、判定は1本で済む。
    static func canFire(slot: Slot, atSeconds seconds: Int, breakSeconds: Int) -> Bool {
        seconds >= slot.blockStart && seconds + breakSeconds <= slot.blockEnd
    }

    // MARK: 表示用

    static func timeString(fromSeconds seconds: Int) -> String {
        let s = ((seconds % secondsPerDay) + secondsPerDay) % secondsPerDay
        return String(format: "%02d:%02d", s / 3600, (s % 3600) / 60)
    }

    /// デバッグモードでは秒単位のグリッドになるため、秒まで出さないと区別がつかない。
    static func preciseTimeString(fromSeconds seconds: Int) -> String {
        let s = ((seconds % secondsPerDay) + secondsPerDay) % secondsPerDay
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
