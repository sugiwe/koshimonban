import SwiftUI
import AppKit

/// Phase 0 の設定画面。
/// 作業時間帯の編集 UI は Phase 1 で入れるため、ここでは読み取り専用で表示する。
struct SettingsView: View {
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
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text(settingsStore.settings.debugMode ? "秒（デバッグモード）" : "分")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("休憩の長さ") {
                    HStack {
                        TextField("", value: settings.breakSeconds, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("秒").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("予告") {
                    HStack {
                        TextField("", value: settings.preNotifyMinutes, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("分前（0 で無効）").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("スキップの解禁まで") {
                    HStack {
                        TextField("", value: settings.skipUnlockSeconds, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("秒").foregroundStyle(.secondary)
                    }
                }
            }

            Section("作業時間帯") {
                ForEach(settingsStore.settings.workBlocks) { block in
                    LabeledContent(block.displayString) {
                        Text(weekdayDescription(block.weekdays))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("編集 UI は Phase 1 で追加します。今は settings.json を直接編集してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            }

            Section("開発") {
                Toggle("デバッグモード", isOn: settings.debugMode)
                Text("発動間隔の単位を「分」ではなく「秒」として扱います。テスト用です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Button("Finder で開く") {
                        NSWorkspace.shared.open(AppPaths.supportDirectory)
                    }
                    Button("既定値に戻す") {
                        settingsStore.resetToDefaults()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .frame(minHeight: 520)
        .onDisappear { settingsStore.saveNow() }
    }

    private func weekdayDescription(_ weekdays: [Int]) -> String {
        let names = ["月", "火", "水", "木", "金", "土", "日"]
        guard !weekdays.isEmpty else { return "なし" }
        return weekdays.compactMap { index -> String? in
            guard (1...7).contains(index) else { return nil }
            return names[index - 1]
        }.joined(separator: "・")
    }
}
