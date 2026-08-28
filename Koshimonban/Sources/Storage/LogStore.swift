import Foundation
import Combine

/// 記録の読み書き。月ごとの JSON ファイルに保存する。
///
/// 書き込みは1回の発動が終わるたびに即座に行う。
/// アプリが落ちても記録が消えないようにするため、まとめ書きはしない。
@MainActor
final class LogStore: ObservableObject {

    static let shared = LogStore()

    /// 日付キー（"2026-08-27"）→ その日の記録
    private var cache: [String: [BreakRecord]] = [:]
    /// すでに読み込んだ月キー（"2026-08"）
    private var loadedMonths: Set<String> = []

    /// 記録が変わったことを UI に知らせるためだけの値
    @Published private(set) var revision = 0

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func dayKey(for date: Date) -> String { dayFormatter.string(from: date) }
    static func monthKey(for date: Date) -> String { monthFormatter.string(from: date) }

    // MARK: 読み込み

    /// その日の記録。必要なら該当月のファイルを読み込む。
    func records(for date: Date) -> [BreakRecord] {
        loadMonthIfNeeded(for: date)
        return cache[Self.dayKey(for: date)] ?? []
    }

    private func loadMonthIfNeeded(for date: Date) {
        let month = Self.monthKey(for: date)
        guard !loadedMonths.contains(month) else { return }
        loadedMonths.insert(month)

        let url = AppPaths.logFile(for: date)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: [BreakRecord]].self, from: data)
            for (day, records) in decoded {
                cache[day] = records
            }
        } catch {
            // 壊れていても消さない。退避して、その月は空として続ける。
            AppPaths.quarantine(url)
            NSLog("[Koshimonban] \(month) の記録を読めませんでした: \(error.localizedDescription)")
        }
    }

    // MARK: 書き込み

    func append(_ record: BreakRecord, on date: Date = Date()) {
        loadMonthIfNeeded(for: date)
        let day = Self.dayKey(for: date)
        cache[day, default: []].append(record)
        writeMonth(for: date)
        revision += 1
    }

    private func writeMonth(for date: Date) {
        let month = Self.monthKey(for: date)
        let entries = cache.filter { $0.key.hasPrefix(month) }
        do {
            try AppPaths.ensureDirectories()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(entries)
            try data.write(to: AppPaths.logFile(for: date), options: .atomic)
        } catch {
            NSLog("[Koshimonban] 記録を保存できませんでした: \(error.localizedDescription)")
        }
    }

    // MARK: デバッグ用

    /// ヒートマップの見た目を確認するためのダミーデータ。
    /// 実データを消さないよう、記録が無い日にだけ書き込む。
    func generateDummyData(days: Int = 28) {
        let calendar = Calendar.current
        var written = 0
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            loadMonthIfNeeded(for: date)
            let day = Self.dayKey(for: date)
            guard cache[day] == nil else { continue }

            let weekday = ScheduleGrid.weekdayIndex(for: date, calendar: calendar)
            guard weekday <= 5 else { continue }   // 平日だけ

            let count = Int.random(in: 3...8)
            var records: [BreakRecord] = []
            for index in 0..<count {
                let minutes = 10 * 60 + index * 30
                let time = TimeOfDay(minutesFromMidnight: minutes) ?? TimeOfDay(hour: 10, minute: 0)
                let roll = Int.random(in: 0..<10)
                let result: BreakResult = roll < 6 ? .completed : (roll < 8 ? .short : .skipped)
                records.append(BreakRecord(
                    scheduledAt: time, firedAt: time, result: result,
                    skipReason: result == .skipped ? SkipReason.allCases.randomElement() : nil,
                    shownSeconds: result == .skipped ? Int.random(in: 5...20) : Int.random(in: 120...180),
                    videoTitle: "ダミー"
                ))
            }
            cache[day] = records
            written += 1
        }
        // 触った月をすべて書き出す
        for offset in stride(from: 0, through: days, by: 15) {
            if let date = calendar.date(byAdding: .day, value: -offset, to: Date()) {
                writeMonth(for: date)
            }
        }
        revision += 1
        NSLog("[Koshimonban] ダミーデータを \(written) 日分生成しました")
    }

    /// 生成したダミーを含め、記録を全部消す。
    func deleteAllRecords() {
        cache.removeAll()
        loadedMonths.removeAll()
        if let files = try? FileManager.default.contentsOfDirectory(
            at: AppPaths.logsDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                try? FileManager.default.removeItem(at: file)
            }
        }
        revision += 1
    }
}
