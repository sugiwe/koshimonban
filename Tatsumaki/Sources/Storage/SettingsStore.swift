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
            NSLog("[Tatsumaki] データディレクトリを作成できませんでした: \(error)")
        }

        let (loaded, warning) = Self.load()
        self.settings = loaded
        self.loadWarning = warning

        // 初回起動でファイルが無い場合、既定値をそのまま書き出しておく。
        // 「どこに何が保存されるのか」を最初から目で見て確認できるようにするため。
        if !FileManager.default.fileExists(atPath: AppPaths.settingsFile.path) {
            saveNow()
        }
    }

    // MARK: 読み込み

    private static func load() -> (AppSettings, String?) {
        let url = AppPaths.settingsFile
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (.default, nil)
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
            return (decoded, nil)
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
            NSLog("[Tatsumaki] settings.json を保存できませんでした: \(error)")
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
