import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VideosTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section {
                ForEach($settingsStore.settings.videos) { $video in
                    VideoRow(video: $video) {
                        settingsStore.settings.videos.removeAll { $0.id == video.id }
                        VideoRotator.shared.reset()
                    }
                }
                if settingsStore.settings.videos.isEmpty {
                    Text("未登録。この状態でも休憩は動きます（テキストとカウントダウンのみ）。")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button {
                        settingsStore.settings.videos.append(
                            VideoEntry(title: "", kind: .youtube, url: "")
                        )
                        VideoRotator.shared.reset()
                    } label: {
                        Label("YouTube を追加", systemImage: "plus")
                    }
                    Button {
                        chooseLocalFile()
                    } label: {
                        Label("ファイルを追加", systemImage: "folder")
                    }
                }
            } header: {
                Text("動画")
            } footer: {
                Text("複数登録すると発動ごとに切り替わります（前回と同じものは続けて出しません）。"
                     + "再生できなかった場合はテキストとカウントダウンだけの表示に切り替わるので、"
                     + "動画が出ないせいで休憩が流れることはありません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func chooseLocalFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.prompt = "追加"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settingsStore.settings.videos.append(
            VideoEntry(title: url.deletingPathExtension().lastPathComponent,
                       kind: .local, path: url.path)
        )
        VideoRotator.shared.reset()
    }
}

private struct VideoRow: View {
    @Binding var video: VideoEntry
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("タイトル（任意）", text: $video.title)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            switch video.kind {
            case .youtube:
                TextField("YouTube の URL", text: Binding(
                    get: { video.url ?? "" },
                    set: { video.url = $0 }
                ))
                .font(.system(.caption, design: .monospaced))

                if let url = video.url, !url.isEmpty {
                    if let id = YouTubeURL.videoID(from: url) {
                        Label("動画 ID: \(id)", systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.green)
                    } else {
                        Label("この URL から動画 ID を読み取れません", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

            case .local:
                Text(video.path ?? "（パス未設定）")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)

                if let path = video.path, !FileManager.default.fileExists(atPath: path) {
                    Label("ファイルが見つかりません", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
