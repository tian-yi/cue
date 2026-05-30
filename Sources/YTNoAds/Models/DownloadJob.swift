import Foundation

enum DownloadStatus: Equatable {
    case queued
    case running
    case complete(URL)
    case failed(String)
}

struct DownloadJob: Identifiable, Equatable {
    let id: UUID
    let video: VideoSummary
    var quality: DownloadQuality
    var status: DownloadStatus
    var progress: Double
    var detail: String
    var createdAt: Date
    var completedAt: Date?

    var isActive: Bool {
        switch status {
        case .queued, .running:
            return true
        case .complete, .failed:
            return false
        }
    }
}
