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
            NSLog("[Koshimonban] データディレクトリを作成できませんでした: \(error)")
        }

        let (loaded, warning) = Self.load()
        self.settings = loaded
        self.loadWarning = warning

        // 初回起動でファイルが無い場合、既定値をそのまま書き出しておく。
        // 「どこに何が保存されるのか」を最初から目で見て確認できるようにするため。
        // 移行した場合も、新しい形で書き直しておく。
        if !FileManager.default.fileExists(atPath: AppPaths.settingsFile.path) || Self.needsRewrite {
            saveNow()
        }
    }

    // MARK: 読み込み

    /// 読み込んだファイルが現在の形式と違った場合に true。呼び出し側で書き直す。
    private static var needsRewrite = false

    private static func load() -> (AppSettings, String?) {
        let url = AppPaths.settingsFile
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (.default, nil)
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
            if fileVersion != AppSettings.currentVersion { needsRewrite = true }

            guard isLegacy else { return (decoded, nil) }

            // 移行前のファイルを残す。移行の結果が意図と違ったとき、
            // 元が消えていると何を設定していたか分からなくなるため。
            let backup = url.appendingPathExtension("v1-backup")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            needsRewrite = true

            return (decoded, "作業時間帯の設定を、曜日ごとの形に移行しました。"
                    + "移行前のファイルは settings.json.v1-backup として残してあります。")
        } catch {
            AppPaths.quarantine(url)
            return (.default, "settings.json を読めなかったため既定値で起動しました。壊れたファイルは同じフォルダに .corrupt-… として残してあります。（\(error.localizedDescription)）")
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
            NSLog("[Koshimonban] settings.json を保存できませんでした: \(error)")
        }
    }

    func dismissLoadWarning() {
        loadWarning = nil
    }

    /// 既定値に戻す（設定を壊してしまった時の逃げ道）
    func resetToDefaults() {
        settings = .default
        saveNow()
    }
}
