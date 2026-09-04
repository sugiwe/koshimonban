import SwiftUI
import AppKit

struct GeneralSettingsTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var launchAgent: LaunchAgentManager

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
                            .onSubmit { settingsStore.clampValues() }
                            .frame(width: 60).multilineTextAlignment(.trailing)
                        Text(settingsStore.settings.debugMode ? "秒（デバッグモード）" : "分")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("休憩の長さ") {
                    HStack {
                        TextField("", value: settings.breakSeconds, format: .number)
                            .onSubmit { settingsStore.clampValues() }
                            .frame(width: 60).multilineTextAlignment(.trailing)
                        Text("秒").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("予告") {
                    HStack {
                        TextField("", value: settings.preNotifyMinutes, format: .number)
                            .onSubmit { settingsStore.clampValues() }
                            .frame(width: 60).multilineTextAlignment(.trailing)
                        Text("分前（0 で無効）").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("スキップの解禁まで") {
                    HStack {
                        TextField("", value: settings.skipUnlockSeconds, format: .number)
                            .onSubmit { settingsStore.clampValues() }
                            .frame(width: 60).multilineTextAlignment(.trailing)
                        Text("秒").foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle("ログイン時に自動起動", isOn: Binding(
                    get: { launchAgent.isInstalled },
                    set: { enabled in
                        // 自動起動の真偽は plist の有無が唯一の事実。
                        // settings.json に別途持つと、書いてある値と実態がずれる。
                        if enabled { launchAgent.install() } else { launchAgent.uninstall() }
                    }
                ))

                if launchAgent.isInstalled {
                    Text(launchAgent.registeredPath ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.head)
                }

                if launchAgent.isStale {
                    Label("登録されているパスが、いま動いているアプリと違います。もう一度オンにし直してください。",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }

                if launchAgent.isOutsideApplications {
                    Label("アプリが /Applications の外にあります。ビルド先が変わると自動起動が壊れるので、"
                          + "常用するなら .app を /Applications に移してから登録し直してください。",
                          systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let error = launchAgent.lastError {
                    Label(error, systemImage: "xmark.octagon")
                        .font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("起動")
            } footer: {
                Text("LaunchAgent として登録します。異常終了した場合は自動で復帰しますが、"
                     + "メニューの「終了」で終わらせた場合は起動し直しません。")
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
