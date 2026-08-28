import SwiftUI

struct WorkBlocksTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var scheduler: Scheduler

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    ForEach($settingsStore.settings.workBlocks) { $block in
                        WorkBlockRow(block: $block) {
                            settingsStore.settings.workBlocks.removeAll { $0.id == block.id }
                        }
                    }
                    if settingsStore.settings.workBlocks.isEmpty {
                        Text("作業時間帯がありません。この状態では一度も発動しません。")
                            .foregroundStyle(.orange)
                    }
                    Button {
                        settingsStore.settings.workBlocks.append(
                            WorkBlock(start: TimeOfDay(hour: 10, minute: 0),
                                      end:   TimeOfDay(hour: 12, minute: 0),
                                      weekdays: [1, 2, 3, 4, 5])
                        )
                    } label: {
                        Label("作業時間帯を追加", systemImage: "plus")
                    }
                } header: {
                    Text("作業時間帯")
                } footer: {
                    Text("発動時刻は、各時間帯の開始時刻を起点とした固定グリッドで決まります。"
                         + "スキップしてもグリッドはズレません。時間帯の終わりに休憩が収まらない場合は発動しません。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("今日の発動予定") {
                    TodaysScheduleList()
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct WorkBlockRow: View {
    @Binding var block: WorkBlock
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DatePicker("", selection: startBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Text("–").foregroundStyle(.secondary)
                DatePicker("", selection: endBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { weekday in
                    let isOn = block.weekdays.contains(weekday)
                    Button(WorkBlock.weekdayNames[weekday - 1]) {
                        block.setWeekday(weekday, enabled: !isOn)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 28, height: 24)
                    .background(isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1))
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }

            if !block.isValid {
                Label("終了が開始より前です。日付をまたぐ時間帯は未対応です。",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            } else if block.weekdays.isEmpty {
                Label("曜日が1つも選ばれていないため、この時間帯は使われません。",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private var startBinding: Binding<Date> {
        Binding(get: { block.start.asDate }, set: { block.start = TimeOfDay(date: $0) })
    }
    private var endBinding: Binding<Date> {
        Binding(get: { block.end.asDate }, set: { block.end = TimeOfDay(date: $0) })
    }
}

/// 設定を変えた結果、実際に何時に発動するのかをその場で見せる。
/// 固定グリッドと境界条件は頭で追いにくいので、目で確認できるようにしておく。
private struct TodaysScheduleList: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        let settings = settingsStore.settings
        let slots = ScheduleGrid.slots(settings: settings, date: Date())

        if slots.isEmpty {
            Text("今日は発動しません（曜日が対象外、または休憩が時間帯に収まりません）")
                .foregroundStyle(.secondary)
        } else {
            Text("\(slots.count) 回")
                .font(.caption).foregroundStyle(.secondary)
            Text(slots.map { formatted($0.at, settings: settings) }.joined(separator: "  "))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func formatted(_ seconds: Int, settings: AppSettings) -> String {
        settings.debugMode
            ? ScheduleGrid.preciseTimeString(fromSeconds: seconds)
            : ScheduleGrid.timeString(fromSeconds: seconds)
    }
}
