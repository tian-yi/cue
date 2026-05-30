import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding()

            Divider()

            if appModel.isSearching {
                ProgressView("Searching")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = appModel.statusMessage, appModel.results.isEmpty {
                ContentUnavailableView(
                    message,
                    systemImage: "magnifyingglass",
                    description: helperRecoveryText
                )
            } else if appModel.results.isEmpty {
                ContentUnavailableView(
                    "Search YouTube",
                    systemImage: "magnifyingglass",
                    description: Text("Results download before playback.")
                )
            } else {
                switch appModel.videoLayoutMode {
                case .gallery:
                    VideoGalleryView(
                        videos: appModel.results,
                        selectedVideoID: appModel.selectedVideo?.id,
                        accessory: activeAccessory(for:),
                        action: appModel.selectAndDownload
                    )
                case .list:
                    List(appModel.results) { video in
                        Button {
                            appModel.selectAndDownload(video)
                        } label: {
                            VideoResultRow(video: video, accessory: activeAccessory(for: video))
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(appModel.selectedVideo?.id == video.id ? Color.accentColor.opacity(0.14) : Color.clear)
                    }
                    .listStyle(.inset)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            searchBar

            Picker("View", selection: $appModel.videoLayoutMode) {
                ForEach(VideoLayoutMode.allCases) { mode in
                    Image(systemName: mode.systemImage)
                        .tag(mode)
                        .help(mode.title)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 92)
            .labelsHidden()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search YouTube", text: $appModel.searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    appModel.performSearch()
                }

            Button {
                appModel.performSearch()
            } label: {
                Image(systemName: "arrow.right")
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.isSearching)
            .help("Search")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var helperRecoveryText: Text? {
        if case .missing = appModel.helperStatus {
            return Text("Install yt-dlp with Homebrew, then relaunch or set the binary path in Settings.")
        }
        return nil
    }

    private func activeAccessory(for video: VideoSummary) -> String? {
        guard let job = appModel.jobs.first(where: { $0.video.id == video.id }) else {
            return nil
        }

        switch job.status {
        case .queued:
            return "Queued"
        case .running:
            if appModel.currentPlayback?.video.id == video.id,
               case .preview = appModel.currentPlayback?.sourceKind {
                return job.quality == .best ? "Upgrading" : "Preview"
            }
            return "\(Int(job.progress * 100))%"
        case .complete:
            return job.quality == .best ? "Best Ready" : "Ready"
        case .failed:
            return "Failed"
        }
    }
}

struct VideoResultRow: View {
    let video: VideoSummary
    var accessory: String?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: video.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .foregroundStyle(.secondary)
                        }
                case .empty:
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                        }
                @unknown default:
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 112, height: 63)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 7) {
                    Text(video.channelTitle)
                    Text(video.displayDuration)
                    if !AppFormatters.compactCount(video.viewCount).isEmpty {
                        Text("\(AppFormatters.compactCount(video.viewCount)) views")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let accessory {
                Text(accessory)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 5)
    }
}
