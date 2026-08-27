import SwiftUI
import AppKit

struct MenuBarContent: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("設定を開く") {
            // メニューバー常駐アプリ（.accessory）は自分で前面に出ないと
            // 設定ウィンドウが他アプリの後ろに開いてしまう。
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("今すぐ発動") {
            // Phase 1 でスケジューラとオーバーレイを繋ぐ。
            NSLog("[Tatsumaki] 「今すぐ発動」が押されました（Phase 1 で実装）")
        }

        Divider()

        Button("設定フォルダを開く") {
            NSWorkspace.shared.open(AppPaths.supportDirectory)
        }

        Divider()

        Button("Tatsumaki を終了") {
            settingsStore.saveNow()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
