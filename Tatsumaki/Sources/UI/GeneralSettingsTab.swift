import SwiftUI
import AppKit

struct GeneralSettingsTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    private var settings: Binding<AppSettings> { $settingsStore.settings }

    var body: some View {
        Form {
            if let warning = settingsStore.loadWarning {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("この警告を閉じる") { settingsStore.dismissLoadWarning() }
                }
            }

            Section("タイミング") {
                LabeledContent("発動の間隔") {
                    HStack {
                        TextField("", value: settings.intervalMinutes, format: .number)
                            .frame(width: 60).multilineTextAlignment(.trailing)
                        Text(settingsStore.settings.debugMode ? "秒（デバッグモード）" : "分")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("休憩の長さ") {
                    HStack {
                        TextField("", value: settings.breakSeconds, format: .number)
                            .frame(width: 60).multilineTextAlignment(.trailing)
                        Text("秒").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("予告") {
                    HStack {
                        TextField("", value: settings.preNotifyMinutes, format: .number)
                            .frame(width: 60).multilineTextAlignment(.trailing)
                        Text("分前（0 で無効）").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("スキップの解禁まで") {
                    HStack {
                        TextField("", value: settings.skipUnlockSeconds, format: .number)
                            .frame(width: 60).multilineTextAlignment(.trailing)
                        Text("秒").foregroundStyle(.secondary)
                    }
                }
            }

            Section("動画") {
                if settingsStore.settings.videos.isEmpty {
                    Text("未登録（テキストとカウントダウンのみ表示されます）")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settingsStore.settings.videos) { video in
                        LabeledContent(video.displayTitle) {
                            Text(video.kind.displayName).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("登録 UI は Phase 2 で追加します。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !settingsStore.settings.validationErrors.isEmpty {
                Section("設定の問題") {
                    ForEach(settingsStore.settings.validationErrors, id: \.self) { error in
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("保存先") {
                Text(AppPaths.supportDirectory.path)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                HStack {
                    Button("Finder で開く") { NSWorkspace.shared.open(AppPaths.supportDirectory) }
                    Button("既定値に戻す") { settingsStore.resetToDefaults() }
                }
            }
        }
        .formStyle(.grouped)
    }
}
