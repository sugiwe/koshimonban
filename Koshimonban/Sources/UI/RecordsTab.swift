import SwiftUI

/// 記録タブ。
///
/// 達成を褒めるためではなく、**サボりのパターンを見つけるため**の画面。
/// スキップの回数と理由の内訳は常に前に置く。
struct RecordsTab: View {
    @EnvironmentObject private var logStore: LogStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        // logStore.revision を読むことで、記録が増えたら再描画される
        let _ = logStore.revision
        let stats28 = BreakStatistics.build(from: logStore, dayCount: 28)
        let stats7 = BreakStatistics.build(from: logStore, dayCount: 7)
        let stats30 = BreakStatistics.build(from: logStore, dayCount: 30)
        let todayRecords = logStore.records(for: Date())

        Form {
            Section("達成率") {
                HStack(spacing: 32) {
                    RateBadge(title: "直近7日", stats: stats7)
                    RateBadge(title: "直近30日", stats: stats30)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("スキップ") {
                if stats30.totalSkipped == 0 {
                    Text("直近30日でスキップはありません")
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("直近30日のスキップ") {
                        Text("\(stats30.totalSkipped) 回")
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }
                    ForEach(SkipReason.allCases) { reason in
                        let count = stats30.skipReasonCounts[reason] ?? 0
                        if count > 0 {
                            LabeledContent(reason.displayName) { Text("\(count) 回") }
                        }
                    }
                    if stats30.skipWithoutReason > 0 {
                        LabeledContent("理由なし") { Text("\(stats30.skipWithoutReason) 回") }
                    }
                }
            }

            Section("直近28日") {
                HeatmapView(stats: stats28)
            }

            Section("今日") {
                if todayRecords.isEmpty {
                    Text("まだ記録がありません").foregroundStyle(.secondary)
                } else {
                    ForEach(todayRecords) { record in
                        HStack {
                            Text(record.scheduledAt.displayString)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(record.result.displayName)
                                .foregroundStyle(color(for: record.result))
                            if let reason = record.skipReason {
                                Text("（\(reason.displayName)）")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if record.shownSeconds > 0 {
                                Text("\(record.shownSeconds)秒")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if settingsStore.settings.debugMode {
                Section {
                    Text("デバッグモード中は記録されません。開発中の発動で実データが埋まるのを防ぐためです。")
                        .font(.caption).foregroundStyle(.orange)
                    HStack {
                        Button("ダミーデータを生成") { logStore.generateDummyData() }
                        Button("記録をすべて削除", role: .destructive) { logStore.deleteAllRecords() }
                    }
                } header: {
                    Text("開発")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func color(for result: BreakResult) -> Color {
        switch result {
        case .completed: .green
        case .short:     .teal
        case .skipped:   .orange
        case .missed:    .secondary
        case .paused:    .secondary
        }
    }
}

private struct RateBadge: View {
    let title: String
    let stats: BreakStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(stats.ratePercentText)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("\(stats.totalAchieved) / \(stats.totalCount)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// 28日分のカレンダー状ヒートマップ。曜日で列が揃うように前を詰める。
private struct HeatmapView: View {
    let stats: BreakStatistics

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(WorkBlock.weekdayNames, id: \.self) { name in
                    Text(name).font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(0..<leadingPadding, id: \.self) { _ in
                    Color.clear.frame(width: 30, height: 30)
                }
                ForEach(stats.days) { day in
                    DayCell(day: day)
                }
            }
            HStack(spacing: 6) {
                Text("低").font(.caption2).foregroundStyle(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.opacity(0.12 + level * 0.78))
                        .frame(width: 14, height: 14)
                }
                Text("高").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("記録なしの日は枠だけ表示されます")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// 先頭の日の曜日に合わせて空セルを入れる
    private var leadingPadding: Int {
        guard let first = stats.days.first else { return 0 }
        return ScheduleGrid.weekdayIndex(for: first.date) - 1
    }
}

private struct DayCell: View {
    let day: BreakStatistics.DaySummary

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: day.hasRecords ? 0 : 1)
            )
            .frame(width: 30, height: 30)
            .overlay(
                Text(dayNumber)
                    .font(.system(size: 10))
                    .foregroundStyle(day.hasRecords && day.rate > 0.5 ? .white : .secondary)
            )
            .help(tooltip)
    }

    private var fillColor: Color {
        guard day.hasRecords else { return .clear }
        return Color.green.opacity(0.12 + day.rate * 0.78)
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: day.date))
    }

    private var tooltip: String {
        guard day.hasRecords else { return "記録なし" }
        let skipText = day.skipped > 0 ? " / スキップ \(day.skipped)" : ""
        return "\(day.achieved)/\(day.total)\(skipText)"
    }
}
