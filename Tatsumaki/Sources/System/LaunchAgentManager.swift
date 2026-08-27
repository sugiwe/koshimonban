import Foundation
import AppKit
import Combine

/// ログイン時の自動起動を LaunchAgent で行う。
///
/// `SMAppService.mainApp` を使わない理由:
/// あちらは正しいコード署名を要求する。Apple Developer Program に入らないローカルビルドでは
/// 無料 Apple ID の証明書が7日で失効し、アプリが起動しなくなる。
/// 毎週ビルドし直す運用は「意志に頼らない」というこのアプリの前提と正面から衝突する。
///
/// 副次的な利点として `KeepAlive` で **クラッシュ時に自動復帰** させられる。
/// 「アプリを殺されたら終わり」というこのアプリ固有の弱点への保険になる。
@MainActor
final class LaunchAgentManager: ObservableObject {

    static let shared = LaunchAgentManager()

    static let label = "net.sugiwe.tatsumaki"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    @Published private(set) var isInstalled = false
    @Published private(set) var registeredPath: String?
    @Published private(set) var lastError: String?

    private var currentExecutablePath: String {
        Bundle.main.executableURL?.path ?? ""
    }

    /// 登録されているパスが、いま動いているアプリと食い違っていないか。
    /// ビルド先を変えたり .app を移動したりすると起こる。
    var isStale: Bool {
        guard isInstalled, let registeredPath else { return false }
        return registeredPath != currentExecutablePath
    }

    /// アプリが /Applications の外にある場合、移動やビルドで自動起動が壊れやすい。
    var isOutsideApplications: Bool {
        !Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    var appBundlePath: String { Bundle.main.bundleURL.path }

    init() {
        refresh()
    }

    // MARK: 状態の取得

    func refresh() {
        let url = Self.plistURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            isInstalled = false
            registeredPath = nil
            return
        }
        isInstalled = true
        registeredPath = (plist["ProgramArguments"] as? [String])?.first
    }

    // MARK: 登録 / 解除

    func install() {
        lastError = nil
        let executable = currentExecutablePath
        guard !executable.isEmpty else {
            lastError = "アプリの実行ファイルの場所が分かりませんでした"
            return
        }

        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            // 異常終了したときだけ復帰させる。
            // 単に true にすると、メニューの「終了」で終わらせても即座に起動し直されてしまい、
            // 逃げ道が塞がる。
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Interactive",
        ]

        do {
            let directory = Self.plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: Self.plistURL, options: .atomic)
        } catch {
            lastError = "設定ファイルを書き出せませんでした: \(error.localizedDescription)"
            return
        }

        // 古い登録が残っていると bootstrap が失敗するので、先に外す
        _ = runLaunchctl(["bootout", "gui/\(getuid())/\(Self.label)"])
        let result = runLaunchctl(["bootstrap", "gui/\(getuid())", Self.plistURL.path])
        if result.status != 0 {
            lastError = "launchctl に登録できませんでした: \(result.output)"
        }
        refresh()
    }

    func uninstall() {
        lastError = nil
        _ = runLaunchctl(["bootout", "gui/\(getuid())/\(Self.label)"])
        try? FileManager.default.removeItem(at: Self.plistURL)
        refresh()
    }

    // MARK: launchctl

    private func runLaunchctl(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (process.terminationStatus, output)
    }
}
