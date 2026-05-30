import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.headline)
                Spacer()
                Button {
                    appModel.clearCompletedJobs()
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Clear completed")
            }
            .padding()

            Divider()

            if appModel.jobs.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Search for a video and select a result.")
                )
            } else {
                List(appModel.jobs) { job in
                    DownloadRow(job: job)
                        .padding(.vertical, 6)
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct DownloadRow: View {
    @EnvironmentObject private var appModel: AppModel
    let job: DownloadJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(job.video.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                    Text(job.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                actions
            }

            switch job.status {
            case .queued, .running:
                ProgressView(value: job.progress)
            case .complete:
                EmptyView()
            case .failed(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch job.status {
        case .queued, .running:
            ProgressView()
                .controlSize(.small)
        case .complete(let url):
            Button {
                appModel.reveal(url)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")

            Button(role: .destructive) {
                appModel.deleteDownloadedFile(for: job)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete")
        case .failed:
            Button {
                appModel.retry(job)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Retry")
        }
    }
}

