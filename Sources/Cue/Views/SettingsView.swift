import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("yt-dlp") {
                HStack {
                    TextField("Binary path", text: $appModel.ytDlpPath)
                    Button {
                        appModel.chooseYTDLPBinary()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Choose binary")

                    Button {
                        appModel.autoDetectYTDLP()
                    } label: {
                        Image(systemName: "scope")
                    }
                    .help("Auto-detect")
                }

                helperStatus
            }

            Section("Download") {
                Picker("Quality", selection: $appModel.downloadQuality) {
                    ForEach(DownloadQuality.allCases) { quality in
                        Text(quality.title)
                            .tag(quality)
                    }
                }

                Text(appModel.downloadQuality.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cache") {
                HStack {
                    Text(appModel.cacheDirectory.path)
                        .font(.callout.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        appModel.reveal(appModel.cacheDirectory)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Reveal in Finder")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var helperStatus: some View {
        switch appModel.helperStatus {
        case .checking:
            Label("Checking", systemImage: "clock")
                .foregroundStyle(.secondary)
        case .available(let path, let version):
            VStack(alignment: .leading, spacing: 4) {
                Label("Available: \(version)", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Text(path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        case .missing:
            Label("Install with: brew install yt-dlp", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("Unavailable", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}
