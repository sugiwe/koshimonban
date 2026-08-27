import SwiftUI

/// メニューバーのアイコンと当日の達成状況。
struct MenuBarLabel: View {
    @EnvironmentObject private var scheduler: Scheduler
    @EnvironmentObject private var logStore: LogStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        // revision と設定を読むことで、記録や設定が変わったら描き直される
        let _ = logStore.revision
        let progress = BreakRecorder.todayProgress()

        HStack(spacing: 3) {
            Image(systemName: scheduler.isPaused ? "figure.stand" : "figure.flexibility")
            if progress.planned > 0 && !settingsStore.settings.debugMode {
                Text("\(progress.achieved)/\(progress.planned)")
            }
        }
        // 一時停止中はアイコンを薄くして、見て分かるようにする
        .opacity(scheduler.isPaused ? 0.45 : 1.0)
    }
}
