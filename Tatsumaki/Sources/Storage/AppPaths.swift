import Foundation

/// アプリのデータ置き場。
///
/// ~/Library/Application Support/Tatsumaki/
///   settings.json
///   logs/YYYY-MM.json
enum AppPaths {
    static let directoryName = "Tatsumaki"

    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    static var settingsFile: URL {
        supportDirectory.appendingPathComponent("settings.json")
    }

    static var logsDirectory: URL {
        supportDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    static func logFile(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return logsDirectory.appendingPathComponent("\(formatter.string(from: date)).json")
    }

    /// 起動時に一度呼ぶ。存在すれば何もしない。
    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }

    /// 壊れた JSON を読み飛ばすとき、消さずに退避しておく。
    /// 「読めなかったので初期化しました」で原因が追えなくなるのを避けるため。
    static func quarantine(_ url: URL) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let stamp = formatter.string(from: Date())
        let destination = url.appendingPathExtension("corrupt-\(stamp)")
        try? FileManager.default.moveItem(at: url, to: destination)
        NSLog("[Tatsumaki] 壊れたファイルを退避しました: \(destination.path)")
    }
}
