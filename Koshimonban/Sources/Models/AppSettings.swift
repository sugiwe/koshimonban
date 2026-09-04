import Foundation

/// settings.json の中身。
///
/// デコードはすべて `decodeIfPresent` + 既定値で行う。
/// このファイルは人間が直接開いて編集することを想定しており、
/// キーが1つ欠けただけで設定全体が読めなくなるのを避けるため。
struct AppSettings: Codable, Equatable {
    var version: Int
    var schedule: WeekSchedule
    /// 設定画面の時間割表で表示する時間の範囲（時）。編集できるのはこの範囲だけ。
    var gridStartHour: Int
    var gridEndHour: Int
    var intervalMinutes: Int
    var breakSeconds: Int
    var preNotifyMinutes: Int
    var skipUnlockSeconds: Int
    var videos: [VideoEntry]
    var launchAtLogin: Bool
    var debugMode: Bool
    /// デバッグモード時、作業時間帯の判定を無視して常に作業中とみなす
    var debugIgnoreWorkBlocks: Bool

    static let currentVersion = 2

    static let `default` = AppSettings(
        version: currentVersion,
        schedule: WeekSchedule(days: Dictionary(uniqueKeysWithValues: Weekday.weekdays.map {
            ($0, [TimeRange(start: TimeOfDay(hour: 10, minute: 0), end: TimeOfDay(hour: 12, minute: 0)),
                  TimeRange(start: TimeOfDay(hour: 14, minute: 0), end: TimeOfDay(hour: 17, minute: 0))])
        })),
        gridStartHour: 6,
        gridEndHour: 24,
        intervalMinutes: 30,
        breakSeconds: 180,
        preNotifyMinutes: 1,
        skipUnlockSeconds: 5,
        videos: [],
        launchAtLogin: true,
        debugMode: false,
        debugIgnoreWorkBlocks: false
    )

    init(version: Int, schedule: WeekSchedule, gridStartHour: Int, gridEndHour: Int,
         intervalMinutes: Int, breakSeconds: Int,
         preNotifyMinutes: Int, skipUnlockSeconds: Int, videos: [VideoEntry],
         launchAtLogin: Bool, debugMode: Bool, debugIgnoreWorkBlocks: Bool) {
        self.version = version
        self.schedule = schedule
        self.gridStartHour = gridStartHour
        self.gridEndHour = gridEndHour
        self.intervalMinutes = intervalMinutes
        self.breakSeconds = breakSeconds
        self.preNotifyMinutes = preNotifyMinutes
        self.skipUnlockSeconds = skipUnlockSeconds
        self.videos = videos
        self.launchAtLogin = launchAtLogin
        self.debugMode = debugMode
        self.debugIgnoreWorkBlocks = debugIgnoreWorkBlocks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        self.init(
            // 保存するのは常に現在の形式なので、読み込んだ値ではなく現在の版を持つ。
            // ファイルに書かれた版と中身が食い違うと、次に読むときの判断を誤る。
            version:           Self.currentVersion,
            schedule:          try Self.decodeSchedule(from: decoder) ?? d.schedule,
            gridStartHour:     try c.decodeIfPresent(Int.self,          forKey: .gridStartHour)     ?? d.gridStartHour,
            gridEndHour:       try c.decodeIfPresent(Int.self,          forKey: .gridEndHour)       ?? d.gridEndHour,
            intervalMinutes:   try c.decodeIfPresent(Int.self,          forKey: .intervalMinutes)   ?? d.intervalMinutes,
            breakSeconds:      try c.decodeIfPresent(Int.self,          forKey: .breakSeconds)      ?? d.breakSeconds,
            preNotifyMinutes:  try c.decodeIfPresent(Int.self,          forKey: .preNotifyMinutes)  ?? d.preNotifyMinutes,
            skipUnlockSeconds: try c.decodeIfPresent(Int.self,          forKey: .skipUnlockSeconds) ?? d.skipUnlockSeconds,
            videos:            try c.decodeIfPresent([VideoEntry].self, forKey: .videos)            ?? d.videos,
            launchAtLogin:     try c.decodeIfPresent(Bool.self,         forKey: .launchAtLogin)     ?? d.launchAtLogin,
            debugMode:         try c.decodeIfPresent(Bool.self,         forKey: .debugMode)         ?? d.debugMode,
            debugIgnoreWorkBlocks: try c.decodeIfPresent(Bool.self,     forKey: .debugIgnoreWorkBlocks) ?? d.debugIgnoreWorkBlocks
        )
    }

    /// v1 の設定ファイルにだけ存在したキー。
    /// `CodingKeys` は現在のプロパティから自動合成されるため、別に用意する。
    private enum LegacyCodingKeys: String, CodingKey {
        case workBlocks
    }

    /// v2 の `schedule` があればそれを、無ければ v1 の `workBlocks` から移行する。
    private static func decodeSchedule(from decoder: Decoder) throws -> WeekSchedule? {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let schedule = try container.decodeIfPresent(WeekSchedule.self, forKey: .schedule) {
            return schedule
        }
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        if let blocks = try legacyContainer.decodeIfPresent([LegacyWorkBlock].self, forKey: .workBlocks) {
            return WeekSchedule.migrating(from: blocks)
        }
        return nil
    }

    /// v1 の形で保存されているか。移行前のファイルを退避すべきかの判断に使う。
    static func isLegacyFormat(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object["schedule"] == nil && object["workBlocks"] != nil
    }

    // MARK: デバッグモードによる読み替え
    //
    // このアプリは実時間で動くため、素のままだと1回のテストに30分かかる。
    // debugMode のときは「分」を「秒」として扱い、開発を現実的な速度にする。

    /// 実際に使う発動間隔（秒）
    var effectiveIntervalSeconds: Int {
        debugMode ? intervalMinutes : intervalMinutes * 60
    }

    /// 実際に使う予告の秒数（0 で無効）。
    /// 間隔と単位を揃えないと、デバッグモードで常に予告が出続けてしまう。
    var effectivePreNotifySeconds: Int {
        debugMode ? preNotifyMinutes : preNotifyMinutes * 60
    }

    /// 設定値の健全性チェック。UI のバリデーション表示に使う。
    var validationErrors: [String] {
        var errors: [String] = []
        if schedule.isEmpty {
            errors.append("作業時間帯が1つも設定されていません。この状態では一度も発動しません。")
        }
        if intervalMinutes < 1 {
            errors.append("間隔は1以上にしてください。")
        }
        if breakSeconds < 1 {
            errors.append("休憩の長さは1秒以上にしてください。")
        }
        if !debugMode && breakSeconds > intervalMinutes * 60 {
            errors.append("休憩の長さが発動間隔より長いため、発動できません。")
        }
        return errors
    }
}
