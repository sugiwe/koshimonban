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
            let scheduler = Scheduler.shared
            // Phase 1b でここをオーバーレイの表示に差し替える。
            scheduler.onFire = { slot, _ in
                NSLog("[Tatsumaki] オーバーレイを出すべき地点（Phase 1b で実装） slot=\(slot.at)")
            }
            scheduler.start()
        }
    }

    /// 設定ウィンドウを閉じてもアプリは常駐し続ける。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 遅延保存の待ち時間中に終了された場合、変更を取りこぼさないよう書き切る。
        MainActor.assumeIsolated {
            SettingsStore.shared.saveNow()
        }
    }
}
