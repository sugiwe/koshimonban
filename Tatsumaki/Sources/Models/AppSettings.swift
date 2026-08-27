import Foundation

/// settings.json の中身。
///
/// デコードはすべて `decodeIfPresent` + 既定値で行う。
/// このファイルは人間が直接開いて編集することを想定しており、
/// キーが1つ欠けただけで設定全体が読めなくなるのを避けるため。
struct AppSettings: Codable, Equatable {
    var version: Int
    var workBlocks: [WorkBlock]
    var intervalMinutes: Int
    var breakSeconds: Int
    var preNotifyMinutes: Int
    var skipUnlockSeconds: Int
    var videos: [VideoEntry]
    var launchAtLogin: Bool
    var debugMode: Bool
    /// デバッグモード時、作業時間帯の判定を無視して常に作業中とみなす
    var debugIgnoreWorkBlocks: Bool

    static let currentVersion = 1

    static let `default` = AppSettings(
        version: currentVersion,
        workBlocks: [
            WorkBlock(start: TimeOfDay(hour: 10, minute: 0),
                      end:   TimeOfDay(hour: 12, minute: 0),
                      weekdays: [1, 2, 3, 4, 5]),
            WorkBlock(start: TimeOfDay(hour: 14, minute: 0),
                      end:   TimeOfDay(hour: 17, minute: 0),
                      weekdays: [1, 2, 3, 4, 5]),
        ],
        intervalMinutes: 30,
        breakSeconds: 180,
        preNotifyMinutes: 1,
        skipUnlockSeconds: 5,
        videos: [],
        launchAtLogin: true,
        debugMode: false,
        debugIgnoreWorkBlocks: false
    )

    init(version: Int, workBlocks: [WorkBlock], intervalMinutes: Int, breakSeconds: Int,
         preNotifyMinutes: Int, skipUnlockSeconds: Int, videos: [VideoEntry],
         launchAtLogin: Bool, debugMode: Bool, debugIgnoreWorkBlocks: Bool) {
        self.version = version
        self.workBlocks = workBlocks
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
            version:           try c.decodeIfPresent(Int.self,          forKey: .version)           ?? d.version,
            workBlocks:        try c.decodeIfPresent([WorkBlock].self,  forKey: .workBlocks)        ?? d.workBlocks,
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

    // MARK: デバッグモードによる読み替え
    //
    // このアプリは実時間で動くため、素のままだと1回のテストに30分かかる。
    // debugMode のときは「分」を「秒」として扱い、開発を現実的な速度にする。

    /// 実際に使う発動間隔（秒）
    var effectiveIntervalSeconds: Int {
        debugMode ? intervalMinutes : intervalMinutes * 60
    }

    /// 設定値の健全性チェック。UI のバリデーション表示に使う。
    var validationErrors: [String] {
        var errors: [String] = []
        for block in workBlocks where !block.isValid {
            errors.append("作業時間帯 \(block.displayString) は終了が開始より前です。日付をまたぐ時間帯は未対応です。")
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
