import SwiftUI
import AppKit

@main
struct TatsumakiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore.shared
    @StateObject private var scheduler = Scheduler.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(settingsStore)
                .environmentObject(scheduler)
        } label: {
            // Phase 3 でここに当日の達成状況（3/5）を出す。
            Image(systemName: scheduler.isPaused ? "figure.stand" : "figure.flexibility")
        }

        Settings {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(scheduler)
        }
    }
}

/// SwiftUI の App だけでは拾えないライフサイクルを受け持つ。
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Info.plist の LSUIElement と重複するが、Xcode から直接実行した場合など
        // plist が効かない経路があるため明示しておく。
        NSApp.setActivationPolicy(.accessory)

        MainActor.assumeIsolated {
            wireSchedulerToOverlay()
            Scheduler.shared.start()
        }
    }

    /// 設定ウィンドウを閉じてもアプリは常駐し続ける。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// スケジューラとオーバーレイを繋ぐ。
    @MainActor
    private func wireSchedulerToOverlay() {
        let scheduler = Scheduler.shared
        let overlay = OverlayController.shared
        let settings = SettingsStore.shared

        scheduler.isOverlayVisible = { overlay.isVisible }

        scheduler.onFire = { _, _ in
            overlay.present(breakSeconds: settings.settings.breakSeconds,
                            skipUnlockSeconds: settings.settings.skipUnlockSeconds)
        }

        overlay.onFinish = { result, reason, shownSeconds, _ in
            // Phase 3 でここを記録の保存に繋ぐ。
            let reasonText = reason.map { "・\($0.displayName)" } ?? ""
            NSLog("[Tatsumaki] 休憩終了: \(result.displayName)\(reasonText) / 表示 \(shownSeconds)秒")
            Scheduler.shared.noteBreakFinished(result: result, reason: reason, shownSeconds: shownSeconds)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 遅延保存の待ち時間中に終了された場合、変更を取りこぼさないよう書き切る。
        MainActor.assumeIsolated {
            SettingsStore.shared.saveNow()
        }
    }
}
