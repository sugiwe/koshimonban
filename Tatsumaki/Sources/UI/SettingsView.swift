import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var scheduler: Scheduler

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("一般", systemImage: "gearshape") }

            WorkBlocksTab()
                .tabItem { Label("作業時間帯", systemImage: "calendar") }

            DeveloperTab()
                .tabItem { Label("開発", systemImage: "hammer") }
        }
        .frame(width: 540, height: 560)
        .onDisappear { settingsStore.saveNow() }
    }
}
