import SwiftUI

/// 作業時間帯の設定。時間割表のタイルを塗って編集する。
///
/// 時間帯のリストを積み上げる形をやめた理由:
/// 曜日固定の定例 MTG が多い使い方だと、時間帯ごとに曜日を選び直すのが煩わしい。
/// 週全体を1枚の表で見ながら塗れる方が、実際の予定に合わせやすい。
struct WorkBlocksTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section {
                ScheduleGridEditor()
            } header: {
                Text("作業時間帯")
            } footer: {
                Text("タイルをクリック、またはドラッグでなぞって塗ります。塗った範囲が作業時間帯です。"
                     + "塗り始めたタイルが消えている場合は塗り、点いている場合は消します。"
                     + "30分刻みなので、時刻は :00 と :30 に丸められます。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("表示する範囲") {
                HStack(spacing: 12) {
                    Stepper(value: $settingsStore.settings.gridStartHour, in: 0...23) {
                        Text("\(settingsStore.settings.gridStartHour):00 から")
                            .monospacedDigit()
                    }
                    Stepper(value: $settingsStore.settings.gridEndHour, in: 1...24) {
                        Text("\(settingsStore.settings.gridEndHour):00 まで")
                            .monospacedDigit()
                    }
                }
                Text("表の見える範囲を変えるだけで、設定済みの時間帯は消えません。"
                     + "範囲の外に設定があるときは自動で広げて表示します。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("今日の発動予定") {
                TodaysScheduleList()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 時間割表

private struct ScheduleGridEditor: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    /// ドラッグ中に「塗っている」のか「消している」のか。
    /// 最初に触れたタイルの状態で決めて、ドラッグ中は変えない。
    @State private var paintingOn: Bool?

    private let rowHeight: CGFloat = 26
    private let labelWidth: CGFloat = 24
    private let rowSpacing: CGFloat = 3

    /// 実際に表示する時間の範囲。
    /// 設定した範囲の外に時間帯があると編集も確認もできなくなるので、そこまで広げる。
    private var displayedHours: (start: Int, end: Int) {
        let settings = settingsStore.settings
        var start = min(max(settings.gridStartHour, 0), 23)
        var end = min(max(settings.gridEndHour, start + 1), 24)

        let usedSlots = Weekday.allCases.flatMap { settings.schedule.slots(for: $0) }
        if let earliest = usedSlots.min() {
            start = min(start, earliest * TimeRange.slotMinutes / 60)
        }
        if let latest = usedSlots.max() {
            let endMinutes = (latest + 1) * TimeRange.slotMinutes
            end = max(end, Int((Double(endMinutes) / 60).rounded(.up)))
        }
        return (start, min(end, 24))
    }

    private var firstSlot: Int { displayedHours.start * 60 / TimeRange.slotMinutes }
    private var slotCount: Int {
        max(1, (displayedHours.end - displayedHours.start) * 60 / TimeRange.slotMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let gridWidth = geometry.size.width - labelWidth
                let cellWidth = gridWidth / CGFloat(slotCount)

                VStack(alignment: .leading, spacing: rowSpacing) {
                    HourRuler(firstSlot: firstSlot, slotCount: slotCount,
                              cellWidth: cellWidth, labelWidth: labelWidth)

                    ForEach(Weekday.allCases) { weekday in
                        HStack(spacing: 0) {
                            Text(weekday.displayName)
                                .font(.caption)
                                .foregroundStyle(weekday.isWeekend ? .secondary : .primary)
                                .frame(width: labelWidth, alignment: .leading)

                            DayRow(weekday: weekday,
                                   firstSlot: firstSlot,
                                   slotCount: slotCount,
                                   cellWidth: cellWidth,
                                   height: rowHeight)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in paint(at: value.location, cellWidth: cellWidth) }
                        .onEnded { _ in paintingOn = nil }
                )
            }
            .frame(height: rulerHeight + (rowHeight + rowSpacing) * 7)

            HStack {
                Text("塗った合計: \(settingsStore.settings.schedule.totalRangeCount) 区間")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("すべて消す") {
                    for weekday in Weekday.allCases {
                        settingsStore.settings.schedule[weekday] = []
                    }
                }
                .buttonStyle(.borderless).font(.caption)
            }
        }
    }

    private let rulerHeight: CGFloat = 18

    /// ドラッグ位置からタイルを特定して塗る。
    ///
    /// タイル1つずつにジェスチャを付けるとドラッグが拾えないため、
    /// 表全体で受けて座標から行と列を割り出している。
    private func paint(at location: CGPoint, cellWidth: CGFloat) {
        guard cellWidth > 0 else { return }

        let y = location.y - rulerHeight - rowSpacing
        guard y >= 0 else { return }
        let row = Int(y / (rowHeight + rowSpacing))
        guard row >= 0, row < Weekday.allCases.count else { return }
        let weekday = Weekday.allCases[row]

        let x = location.x - labelWidth
        guard x >= 0 else { return }
        let column = Int(x / cellWidth)
        guard column >= 0, column < slotCount else { return }
        let slot = firstSlot + column

        var slots = settingsStore.settings.schedule.slots(for: weekday)
        // 最初に触れたタイルの状態で、この操作が「塗る」のか「消す」のかを決める
        let shouldTurnOn = paintingOn ?? !slots.contains(slot)
        paintingOn = shouldTurnOn

        let alreadyMatches = slots.contains(slot) == shouldTurnOn
        guard !alreadyMatches else { return }

        if shouldTurnOn { slots.insert(slot) } else { slots.remove(slot) }
        settingsStore.settings.schedule.setSlots(slots, for: weekday)
    }
}

private struct DayRow: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    let weekday: Weekday
    let firstSlot: Int
    let slotCount: Int
    let cellWidth: CGFloat
    let height: CGFloat

    var body: some View {
        let slots = settingsStore.settings.schedule.slots(for: weekday)
        HStack(spacing: 0) {
            ForEach(0..<slotCount, id: \.self) { column in
                let slot = firstSlot + column
                let isOn = slots.contains(slot)
                Rectangle()
                    .fill(isOn ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.10))
                    .frame(width: max(1, cellWidth - 1), height: height)
                    .padding(.trailing, 1)
                    // 1時間ごとの区切りを、境目のタイルを少し暗くして示す
                    .overlay(alignment: .leading) {
                        if slot % 2 == 0 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.18))
                                .frame(width: 1)
                        }
                    }
            }
        }
    }
}

private struct HourRuler: View {
    let firstSlot: Int
    let slotCount: Int
    let cellWidth: CGFloat
    let labelWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: labelWidth, height: 16)
            ForEach(0..<slotCount, id: \.self) { column in
                let slot = firstSlot + column
                let hour = slot * TimeRange.slotMinutes / 60
                // 2時間ごとに目盛りを出す。毎時だと狭くて重なる。
                let showsLabel = slot % 4 == 0
                Text(showsLabel ? "\(hour)" : "")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: max(1, cellWidth), height: 16, alignment: .leading)
            }
        }
    }
}

// MARK: - 今日の発動予定

/// 設定を変えた結果、実際に何時に発動するのかをその場で見せる。
/// 固定グリッドと境界条件は頭で追いにくいので、目で確認できるようにしておく。
private struct TodaysScheduleList: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        let settings = settingsStore.settings
        let slots = ScheduleGrid.slots(settings: settings, date: Date())

        if slots.isEmpty {
            Text("今日は発動しません（時間帯が未設定、または休憩が時間帯に収まりません）")
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
