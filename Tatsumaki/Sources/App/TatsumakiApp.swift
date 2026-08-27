import SwiftUI
import AppKit

@main
struct TatsumakiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore.shared
    @StateObject private var scheduler = Scheduler.shared
    @StateObject private var logStore = LogStore.shared
    @StateObject private var launchAgent = LaunchAgentManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(settingsStore)
                .environmentObject(scheduler)
                .environmentObject(logStore)
        } label: {
            MenuBarLabel()
                .environmentObject(scheduler)
                .environmentObject(logStore)
                .environmentObject(settingsStore)
        }

        Settings {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(scheduler)
                .environmentObject(logStore)
                .environmentObject(launchAgent)
        }
    }
}

/// SwiftUI の App だけでは拾えないライフサイクルを受け持つ。
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LaunchAgent 登録直後は launchd がもう1つ起動してしまう。後発は黙って引き下がる。
        if SingleInstanceGuard.shouldTerminateBecauseAnotherInstanceIsRunning() {
            NSLog("[Tatsumaki] すでに起動しているインスタンスがあるため終了します")
            NSApp.terminate(nil)
            return
        }

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

        scheduler.onFire = { slot, firedAt in
            let video = VideoRotator.shared.next(from: settings.settings.videos)
            overlay.present(breakSeconds: settings.settings.breakSeconds,
                            skipUnlockSeconds: settings.settings.skipUnlockSeconds,
                            video: video,
                            scheduledSeconds: slot.at,
                            firedAt: firedAt)
        }

        overlay.onFinish = { outcome in
            BreakRecorder.record(outcome)
            Scheduler.shared.noteBreakFinished(result: outcome.result,
                                               reason: outcome.skipReason,
                                               shownSeconds: outcome.shownSeconds)
        }

        // 発動できなかった回（取りこぼし・一時停止）も記録に残す。
        // サボりのパターンを見るには、発動しなかった事実も必要なため。
        scheduler.onResult = { slot, result, date in
            BreakRecorder.record(slot: slot, result: result, at: date)
        }

        scheduler.onPreNotify = { _, remaining in
            PreNotifyController.shared.show(secondsUntilBreak: remaining)
        }
        scheduler.onCancelPreNotify = {
            PreNotifyController.shared.dismiss()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 遅延保存の待ち時間中に終了された場合、変更を取りこぼさないよう書き切る。
        MainActor.assumeIsolated {
            SettingsStore.shared.saveNow()
        }
    }
}
