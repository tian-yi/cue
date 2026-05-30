import SwiftUI

struct VideoDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var isBuffering = false

    var body: some View {
        Group {
            if let video = appModel.selectedVideo {
                detail(for: video)
            } else {
                ContentUnavailableView(
                    "No Video Selected",
                    systemImage: "play.rectangle",
                    description: Text("Choose a result to download and play.")
                )
            }
        }
        .navigationTitle(appModel.selectedVideo?.title ?? "Player")
    }

    private func detail(for video: VideoSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            playerArea(for: video)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(video.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(3)

                        Text(video.channelTitle)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    QualityPicker(selection: $appModel.downloadQuality)
                        .frame(width: 122)

                    Button {
                        appModel.closePlayer()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .help("Close player")

                    if let playback = appModel.currentPlayback, playback.video.id == video.id {
                        Button {
                            appModel.openFullscreen(playback)
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                        }
                        .help("Fullscreen")
                    }

                    Button {
                        appModel.openOnYouTube(video)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .help("Open on YouTube")
                }

                if let job = appModel.jobs.first(where: { $0.video.id == video.id }) {
                    jobStatus(job)
                }
            }
            .padding(20)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func playerArea(for video: VideoSummary) -> some View {
        if let playback = appModel.currentPlayback, playback.video.id == video.id {
            ZStack {
                PlayerView(fileURL: playback.fileURL, isBuffering: $isBuffering)
                    .frame(minHeight: 360)
                    .background(.black)

                if isBuffering {
                    BufferingOverlay()
                }

                VStack {
                    HStack {
                        playbackBadge(playback)
                        Spacer()
                        if case .preview = playback.sourceKind {
                            Text("Best download continues in background")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.black.opacity(0.58), in: Capsule())
                        }
                        Spacer()
                        Button {
                            appModel.openFullscreen(playback)
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.borderless)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .help("Fullscreen")
                    }
                    Spacer()
                }
                .padding(12)
            }
            .onChange(of: playback.fileURL) { _, _ in
                isBuffering = true
            }
        } else if let job = appModel.jobs.first(where: { $0.video.id == video.id }), job.isActive {
            VStack(spacing: 18) {
                ProgressView(value: job.progress)
                    .frame(width: 280)
                Text(job.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 360)
            .background(.quaternary)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)

                Button {
                    appModel.selectAndDownload(video)
                } label: {
                    Label("Download", systemImage: "arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 360)
            .background(.quaternary)
        }
    }

    private func playbackBadge(_ playback: PlaybackItem) -> some View {
        Label(playback.sourceKind.title, systemImage: playback.sourceKind.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(badgeColor(for: playback.sourceKind), in: Capsule())
            .help(playback.sourceKind.detail)
    }

    private func badgeColor(for sourceKind: PlaybackSourceKind) -> Color {
        switch sourceKind {
        case .preview:
            return .orange.opacity(0.86)
        case .final:
            return .green.opacity(0.80)
        }
    }

    @ViewBuilder
    private func jobStatus(_ job: DownloadJob) -> some View {
        switch job.status {
        case .queued:
            Label("Queued • \(job.quality.title)", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .running:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(runningLabel(for: job), systemImage: runningIcon(for: job))
                    Spacer()
                    Text("\(Int(job.progress * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: job.progress)
            }
        case .complete(let url):
            HStack {
                Label("Ready • \(job.quality.title)", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Spacer()
                Button {
                    appModel.reveal(url)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Reveal in Finder")
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Download failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                HStack {
                    Button {
                        appModel.retry(job)
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }

                    Button {
                        appModel.openOnYouTube(job.video)
                    } label: {
                        Label("Open", systemImage: "safari")
                    }
                }
            }
        }
    }

    private func runningLabel(for job: DownloadJob) -> String {
        if appModel.currentPlayback?.video.id == job.video.id,
           case .preview = appModel.currentPlayback?.sourceKind {
            return job.quality == .best ? "Preview playing • upgrading to Best" : "Preview playing • caching \(job.quality.title)"
        }

        return "Downloading • \(job.quality.title)"
    }

    private func runningIcon(for job: DownloadJob) -> String {
        if appModel.currentPlayback?.video.id == job.video.id,
           case .preview = appModel.currentPlayback?.sourceKind {
            return "bolt.fill"
        }

        return "arrow.down.circle"
    }
}
