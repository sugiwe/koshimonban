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
                NumberSettingRow(
                    title: "発動の間隔",
                    value: settings.intervalMinutes,
                    range: AppSettings.Limits.interval,
                    unit: settingsStore.settings.debugMode ? "秒（デバッグモード）" : "分")
                NumberSettingRow(
                    title: "休憩の長さ",
                    value: settings.breakSeconds,
                    range: AppSettings.Limits.breakSeconds,
                    unit: "秒")
                NumberSettingRow(
                    title: "予告",
                    value: settings.preNotifyMinutes,
                    range: AppSettings.Limits.preNotifyMinutes,
                    unit: "分前（0 で無効）")
                NumberSettingRow(
                    title: "スキップの解禁まで",
                    value: settings.skipUnlockSeconds,
                    range: AppSettings.Limits.skipUnlockSeconds,
                    unit: "秒")
            }

            Section {
                Toggle("会議中は発動を見送る", isOn: settings.pauseDuringMeetings)
                MeetingStateView()
            } header: {
                Text("会議")
            } footer: {
                Text("マイクかカメラが使われている間は発動しません。会議が終わったら発動します。"
                     + "Zoom・Google Meet・Teams・Slack ハドルなど、アプリを問わず同じように効きます。"
                     + "アプリ内でミュートしていても、多くの場合はマイクを掴んだままなので検知できます。")
                    .font(.caption).foregroundStyle(.secondary)
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

/// いま会議中と判定されているかと、その根拠になっているデバイス。
///
/// 誤検知（録音アプリや音声入力でマイクが使われている等）が起きたときに、
/// どのデバイスが原因かをここで確かめられるようにしておく。
private struct MeetingStateView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var states: [MeetingDetector.DeviceState] = []
    @State private var timer: Timer?

    private let detector = MeetingDetector()

    var body: some View {
        let running = states.filter(\.isRunning)

        VStack(alignment: .leading, spacing: 4) {
            if running.isEmpty {
                Label("いまは会議中ではありません", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("会議中と判定しています", systemImage: "video.fill")
                    .font(.caption).foregroundStyle(.orange)
                ForEach(running) { state in
                    Text("　使用中: \(state.name)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .opacity(settingsStore.settings.pauseDuringMeetings ? 1 : 0.4)
        .onAppear {
            refresh()
            // 設定画面を開いている間だけ、状態を追いかける
            let timer = Timer(timeInterval: 2, repeats: true) { _ in
                MainActor.assumeIsolated { refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func refresh() {
        states = detector.deviceStates()
    }
}

/// 数値の設定1項目。手入力と上下ボタンの両方で変えられる。
///
/// 手入力だけだと、1つ増やすのにキーボードへ持ち替えることになる。
/// 上下ボタンだけだと、大きく変えるのに何度も押すことになる。両方置く。
private struct NumberSettingRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField("", value: clampedValue, format: .number)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Stepper("", value: clampedValue, in: range)
                    .labelsHidden()
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 書き込むときに範囲へ収める。
    ///
    /// 上下ボタンは `in:` で止まるが、手入力は素通しになる。
    /// 桁を打ち間違えただけで、秒への換算があふれてアプリが起動しなくなる経路があるため、
    /// 入った時点で丸めておく。
    private var clampedValue: Binding<Int> {
        Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}
