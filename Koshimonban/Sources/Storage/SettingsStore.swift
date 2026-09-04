import Foundation
import Combine

/// settings.json の読み書きを受け持つ。
///
/// 保存はまとめて遅延実行する（設定画面で1文字打つたびにディスクへ書かないため）。
/// ただしアプリ終了時には必ず書き切る。
@MainActor
final class SettingsStore: ObservableObject {

    /// アプリ終了時に AppDelegate から書き切る必要があるため、単一のインスタンスを共有する。
    static let shared = SettingsStore()

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            scheduleSave()
        }
    }

    /// 読み込み時に問題があった場合の説明。設定画面に出して気づけるようにする。
    @Published private(set) var loadWarning: String?

    private var saveTask: Task<Void, Never>?
    private let saveDelay: Duration = .milliseconds(400)

    init() {
        do {
            try AppPaths.ensureDirectories()
        } catch {
            NSLog("[Koshimonban] データディレクトリを作成できませんでした: %@", String(describing: error))
        }

        let result = Self.load()
        self.settings = result.settings
        self.loadWarning = result.warning

        // 初回起動でファイルが無い場合、既定値をそのまま書き出しておく。
        // 「どこに何が保存されるのか」を最初から目で見て確認できるようにするため。
        // 移行した場合も、新しい形で書き直しておく。
        if !FileManager.default.fileExists(atPath: AppPaths.settingsFile.path) || result.needsRewrite {
            saveNow()
        }
    }

    // MARK: 読み込み

    /// 読み込み結果。`needsRewrite` は「ファイルが現在の形式と違うので書き直すべき」の意。
    /// static var で伝えると、生成の副作用がプロセス全体に残り、
    /// 2つ目のインスタンスを作ったときに互いを踏み合う。戻り値で返す。
    private static func load() -> (settings: AppSettings, warning: String?, needsRewrite: Bool) {
        let url = AppPaths.settingsFile
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (.default, nil, false)
        }
        do {
            let data = try Data(contentsOf: url)
            let isLegacy = AppSettings.isLegacyFormat(data)
            let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

            // ファイルに書かれた版が古ければ、中身が同じでも書き直して揃える。
            var fileVersion: Int?
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                fileVersion = object["version"] as? Int
            }
            let versionDiffers = fileVersion != AppSettings.currentVersion

            guard isLegacy else { return (decoded, nil, versionDiffers) }

            // 移行前のファイルを残す。移行の結果が意図と違ったとき、
            // 元が消えていると何を設定していたか分からなくなるため。
            let backup = url.appendingPathExtension("v1-backup")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)

            return (decoded, "作業時間帯の設定を、曜日ごとの形に移行しました。"
                    + "移行前のファイルは settings.json.v1-backup として残してあります。", true)
        } catch {
            AppPaths.quarantine(url)
            return (.default, "settings.json を読めなかったため既定値で起動しました。壊れたファイルは同じフォルダに .corrupt-… として残してあります。（\(error.localizedDescription)）", true)
        }
    }

    // MARK: 保存

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [saveDelay] in
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    /// 即座にディスクへ書き出す。終了時にも呼ぶこと。
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(settings)
            // .atomic: 書き込み途中で落ちても既存ファイルを壊さない
            try data.write(to: AppPaths.settingsFile, options: .atomic)
        } catch {
            NSLog("[Koshimonban] settings.json を保存できませんでした: %@", String(describing: error))
        }
    }

    func dismissLoadWarning() {
        loadWarning = nil
    }

    /// 入力欄で範囲外の値が入った場合に安全な範囲へ丸める。
    /// AppSettings の init が丸めるので、詰め直すだけで効く。
    func clampValues() {
        settings = AppSettings(
            version: settings.version,
            schedule: settings.schedule,
            gridStartHour: settings.gridStartHour,
            gridEndHour: settings.gridEndHour,
            intervalMinutes: settings.intervalMinutes,
            breakSeconds: settings.breakSeconds,
            preNotifyMinutes: settings.preNotifyMinutes,
            skipUnlockSeconds: settings.skipUnlockSeconds,
            videos: settings.videos,
            debugMode: settings.debugMode,
            debugIgnoreWorkBlocks: settings.debugIgnoreWorkBlocks
        )
    }

    /// 既定値に戻す（設定を壊してしまった時の逃げ道）
    func resetToDefaults() {
        settings = .default
        saveNow()
    }
}
