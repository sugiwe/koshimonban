import SwiftUI

/// スケジューラが「いま何を考えているか」を見せる開発用タブ。
///
/// このアプリは実時間で動くため、素のままでは発動判定のバグを追うのに30分かかる。
/// 判定の根拠をここに全部出しておくことで、オーバーレイを出さずに検証できるようにする。
struct DeveloperTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var scheduler: Scheduler

    private var settings: Binding<AppSettings> { $settingsStore.settings }

    var body: some View {
        Form {
            Section("スケジューラの状態") {
                LabeledContent("状態", value: scheduler.statusLine)
                LabeledContent("次の発動", value: scheduler.nextSlotLine)
                LabeledContent("今日の予定回数", value: "\(scheduler.todaySlotCount) 回")
                HStack {
                    Button("いま判定する") { scheduler.tick() }
                    if scheduler.isPaused {
                        Button("一時停止を解除") { scheduler.resumeFromPause() }
                    } else {
                        Button("30分停止") { scheduler.pause(for: 30 * 60) }
                        Button("今日はもう停止") { scheduler.pauseForRestOfDay() }
                    }
                }
            }

            Section {
                Toggle("デバッグモード", isOn: settings.debugMode)
                Toggle("作業時間帯を無視して常に作業中とみなす", isOn: settings.debugIgnoreWorkBlocks)
                    .disabled(!settingsStore.settings.debugMode)
            } header: {
                Text("デバッグ")
            } footer: {
                Text("デバッグモードでは発動間隔の単位を「分」ではなく「秒」として扱います。"
                     + "間隔30・休憩10 にすれば、30秒ごとに10秒の休憩が来る状態で試せます。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                if scheduler.events.isEmpty {
                    Text("まだ何も起きていません").foregroundStyle(.secondary)
                } else {
                    ForEach(scheduler.events.reversed()) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Text(timeText(event.at))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Image(systemName: icon(for: event.kind))
                                .foregroundStyle(color(for: event.kind))
                                .font(.caption)
                            Text(event.message).font(.caption)
                            Spacer(minLength: 0)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("判定ログ")
                    Spacer()
                    Button("消去") { scheduler.clearEvents() }
                        .buttonStyle(.borderless).font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func icon(for kind: Scheduler.Event.Kind) -> String {
        switch kind {
        case .info:     "info.circle"
        case .fire:     "bolt.fill"
        case .warning:  "exclamationmark.triangle"
        case .resolved: "checkmark.circle"
        }
    }

    private func color(for kind: Scheduler.Event.Kind) -> Color {
        switch kind {
        case .info:     .secondary
        case .fire:     .accentColor
        case .warning:  .orange
        case .resolved: .green
        }
    }
}
