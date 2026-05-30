import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appModel: AppModel

    private var completedJobs: [DownloadJob] {
        appModel.jobs.filter {
            if case .complete = $0.status {
                return true
            }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Library")
                    .font(.headline)
                Spacer()
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
            .padding()

            Divider()

            if completedJobs.isEmpty {
                ContentUnavailableView(
                    "Library Empty",
                    systemImage: "play.rectangle.on.rectangle",
                    description: Text("Completed videos appear here.")
                )
            } else {
                switch appModel.videoLayoutMode {
                case .gallery:
                    VideoGalleryView(
                        videos: completedJobs.map(\.video),
                        selectedVideoID: appModel.selectedVideo?.id,
                        accessory: { _ in "Ready" },
                        action: play
                    )
                case .list:
                    List(completedJobs) { job in
                        Button {
                            play(job.video)
                        } label: {
                            VideoResultRow(video: job.video, accessory: "Ready")
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.inset)
                }
            }
        }
    }

    private func play(_ video: VideoSummary) {
        guard let job = completedJobs.first(where: { $0.video.id == video.id }),
              case .complete(let url) = job.status else {
            return
        }

        appModel.selectedVideo = video
        appModel.currentPlayback = PlaybackItem(
            video: video,
            fileURL: url,
            sourceKind: .final(quality: job.quality)
        )
    }
}
