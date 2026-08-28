import SwiftUI
import AppKit

struct MenuBarContent: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var scheduler: Scheduler
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(scheduler.statusLine)
        Text("次の発動: \(scheduler.nextSlotLine)")

        Divider()

        Button("設定を開く") {
            // メニューバー常駐アプリ（.accessory）は自分で前面に出ないと
            // 設定ウィンドウが他アプリの後ろに開いてしまう。
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("今すぐ発動") { scheduler.fireNow() }

        Divider()

        // 逃げ道。これが無いと、本当に困った時にアプリごと終了され、二度と起動されなくなる。
        if scheduler.isPaused {
            Button("一時停止を解除") { scheduler.resumeFromPause() }
        } else {
            Button("30分停止") { scheduler.pause(for: 30 * 60) }
            Button("1時間停止") { scheduler.pause(for: 60 * 60) }
            Button("今日はもう停止") { scheduler.pauseForRestOfDay() }
        }

        Divider()

        Button("設定フォルダを開く") { NSWorkspace.shared.open(AppPaths.supportDirectory) }

        Divider()

        Button("腰門番を終了") {
            settingsStore.saveNow()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
