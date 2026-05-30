import Foundation
import Hummingbird

struct RemoteServerStatus: Equatable {
    var isEnabled: Bool = false
    var isStarting: Bool = false
    var port: Int = RemoteControlDefaults.port
    var token: String?
    var localURLs: [URL] = []
    var connectedClients: Int = 0
    var errorMessage: String?

    var primaryURL: URL? {
        localURLs.first
    }
}

enum RemoteControlDefaults {
    static let port = 48291
}

enum RemoteControlCommandName: String, Codable {
    case play
    case pause
    case togglePlayPause
    case seekBy
    case seekTo
    case setVolume
    case setQuality
    case toggleFullscreen
    case closePlayer
}

struct RemoteControlCommand: Codable, Equatable {
    let command: RemoteControlCommandName
    let seconds: Double?
    let volume: Double?
    let quality: DownloadQuality?

    init(
        command: RemoteControlCommandName,
        seconds: Double? = nil,
        volume: Double? = nil,
        quality: DownloadQuality? = nil
    ) {
        self.command = command
        self.seconds = seconds
        self.volume = volume
        self.quality = quality
    }
}

struct RemotePlaybackState: Codable, Equatable {
    let appName: String
    let hasVideo: Bool
    let title: String?
    let channel: String?
    let thumbnailURL: URL?
    let webpageURL: URL?
    let isPlaying: Bool
    let isBuffering: Bool
    let currentTime: Double
    let duration: Double
    let volume: Double
    let selectedQuality: DownloadQuality
    let sourceKind: RemotePlaybackSourceKind?
    let downloadState: RemoteDownloadState?
    let availableQualities: [RemoteQualityOption]

    static func empty(
        selectedQuality: DownloadQuality,
        volume: Double
    ) -> RemotePlaybackState {
        RemotePlaybackState(
            appName: "YT No Ads",
            hasVideo: false,
            title: nil,
            channel: nil,
            thumbnailURL: nil,
            webpageURL: nil,
            isPlaying: false,
            isBuffering: false,
            currentTime: 0,
            duration: 0,
            volume: volume,
            selectedQuality: selectedQuality,
            sourceKind: nil,
            downloadState: nil,
            availableQualities: DownloadQuality.allCases.map(RemoteQualityOption.init)
        )
    }
}

struct RemotePlaybackSourceKind: Codable, Equatable {
    let kind: String
    let title: String
    let detail: String
    let quality: DownloadQuality?
    let targetQuality: DownloadQuality?

    init(_ sourceKind: PlaybackSourceKind) {
        switch sourceKind {
        case .preview(let targetQuality):
            self.kind = "preview"
            self.quality = nil
            self.targetQuality = targetQuality
        case .final(let quality):
            self.kind = "final"
            self.quality = quality
            self.targetQuality = nil
        }
        self.title = sourceKind.title
        self.detail = sourceKind.detail
    }
}

struct RemoteDownloadState: Codable, Equatable {
    let status: String
    let progress: Double
    let detail: String
    let quality: DownloadQuality

    init(job: DownloadJob) {
        self.progress = job.progress
        self.detail = job.detail
        self.quality = job.quality

        switch job.status {
        case .queued:
            self.status = "queued"
        case .running:
            self.status = "running"
        case .complete:
            self.status = "complete"
        case .failed:
            self.status = "failed"
        }
    }
}

struct RemoteQualityOption: Codable, Equatable, Identifiable {
    let id: DownloadQuality
    let title: String
    let detail: String

    init(_ quality: DownloadQuality) {
        self.id = quality
        self.title = quality.title
        self.detail = quality.detail
    }
}

struct RemoteCommandResponse: Codable, Equatable {
    let ok: Bool
    let state: RemotePlaybackState
}

struct RemoteSearchRequest: Codable, Equatable {
    let query: String
}

struct RemoteSearchResponse: Codable, Equatable {
    let results: [VideoSummary]
}

struct RemotePlayRequest: Codable, Equatable {
    let videoID: String
}

extension RemotePlaybackState: ResponseEncodable {}
extension RemoteCommandResponse: ResponseEncodable {}
extension RemoteSearchResponse: ResponseEncodable {}
