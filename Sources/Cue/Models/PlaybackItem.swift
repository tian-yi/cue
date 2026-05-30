import Foundation

enum PlaybackSourceKind: Equatable {
    case preview(targetQuality: DownloadQuality)
    case final(quality: DownloadQuality)

    var title: String {
        switch self {
        case .preview(let targetQuality):
            return targetQuality == .best ? "Preview quality" : "Streaming preview"
        case .final(let quality):
            return "\(quality.title) ready"
        }
    }

    var detail: String {
        switch self {
        case .preview(let targetQuality):
            return targetQuality == .best ? "Best quality is downloading in the background." : "The cached file is downloading in the background."
        case .final:
            return "Playing from the completed download."
        }
    }

    var systemImage: String {
        switch self {
        case .preview:
            return "bolt.fill"
        case .final:
            return "checkmark.circle.fill"
        }
    }
}

struct PlaybackItem: Identifiable, Equatable {
    let id: UUID
    let video: VideoSummary
    let fileURL: URL
    let sourceKind: PlaybackSourceKind

    init(video: VideoSummary, fileURL: URL, sourceKind: PlaybackSourceKind) {
        self.id = UUID()
        self.video = video
        self.fileURL = fileURL
        self.sourceKind = sourceKind
    }
}
