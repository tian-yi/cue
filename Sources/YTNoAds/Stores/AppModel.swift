import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: AppSection = .search
    @Published var searchText = ""
    @Published var results: [VideoSummary] = []
    @Published var selectedVideo: VideoSummary?
    @Published var currentPlayback: PlaybackItem? {
        didSet {
            if let currentPlayback {
                playbackController.load(currentPlayback)
            } else {
                playbackController.stop()
                fullscreenPresenter.close()
            }
            publishRemoteState()
        }
    }
    @Published var jobs: [DownloadJob] = []
    @Published var isSearching = false
    @Published var statusMessage: String?
    @Published var helperStatus: HelperStatus = .checking
    @Published var remoteServerStatus = RemoteServerStatus()
    @Published var videoLayoutMode: VideoLayoutMode {
        didSet {
            UserDefaults.standard.set(videoLayoutMode.rawValue, forKey: Self.videoLayoutModeKey)
        }
    }
    @Published var downloadQuality: DownloadQuality {
        didSet {
            UserDefaults.standard.set(downloadQuality.rawValue, forKey: Self.downloadQualityKey)
        }
    }
    @Published var ytDlpPath: String {
        didSet {
            UserDefaults.standard.set(ytDlpPath, forKey: Self.ytDlpPathKey)
            refreshHelperStatus()
        }
    }

    let cacheDirectory: URL
    let playbackController = PlaybackController()

    private static let ytDlpPathKey = "ytDlpPath"
    private static let videoLayoutModeKey = "videoLayoutMode"
    private static let downloadQualityKey = "downloadQuality"
    private let fullscreenPresenter = FullscreenPlayerPresenter()
    private var remoteServer: RemoteControlServer?
    private var playbackStateCancellable: AnyCancellable?

    init() {
        self.ytDlpPath = UserDefaults.standard.string(forKey: Self.ytDlpPathKey) ?? ""
        self.videoLayoutMode = VideoLayoutMode(
            rawValue: UserDefaults.standard.string(forKey: Self.videoLayoutModeKey) ?? ""
        ) ?? .gallery
        self.downloadQuality = DownloadQuality(
            rawValue: UserDefaults.standard.string(forKey: Self.downloadQualityKey) ?? ""
        ) ?? .fastStart
        self.cacheDirectory = Self.defaultCacheDirectory()
        observePlaybackForRemoteState()
        refreshHelperStatus()
    }

    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            statusMessage = "Enter a search term."
            return
        }

        Task {
            do {
                _ = try await search(query: query)
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    @discardableResult
    func search(query: String) async throws -> [VideoSummary] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            statusMessage = "Enter a search term."
            return []
        }

        isSearching = true
        statusMessage = nil

        defer {
            isSearching = false
        }

        let service = currentService()
        let videos = try await service.search(query: trimmedQuery)
        searchText = trimmedQuery
        results = videos
        selectedSection = .search

        if videos.isEmpty {
            statusMessage = "No results."
        }

        return videos
    }

    func selectAndDownload(_ video: VideoSummary) {
        selectedVideo = video
        selectedSection = .search
        if currentPlayback?.video.id != video.id {
            currentPlayback = nil
        }
        publishRemoteState()

        if let existing = jobs.first(where: { $0.video.id == video.id }) {
            switch existing.status {
            case .complete(let url):
                currentPlayback = PlaybackItem(
                    video: video,
                    fileURL: url,
                    sourceKind: .final(quality: existing.quality)
                )
                publishRemoteState()
                return
            case .queued, .running:
                return
            case .failed:
                break
            }
        }

        let job = DownloadJob(
            id: UUID(),
            video: video,
            quality: downloadQuality,
            status: .queued,
            progress: 0,
            detail: "Queued",
            createdAt: Date(),
            completedAt: nil
        )
        jobs.insert(job, at: 0)
        publishRemoteState()
        start(jobID: job.id)
    }

    func retry(_ job: DownloadJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else {
            return
        }

        if currentPlayback?.video.id == job.video.id {
            currentPlayback = nil
            publishRemoteState()
        }

        jobs[index].status = .queued
        jobs[index].quality = downloadQuality
        jobs[index].progress = 0
        jobs[index].detail = "Queued"
        jobs[index].completedAt = nil
        start(jobID: job.id)
        publishRemoteState()
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openOnYouTube(_ video: VideoSummary) {
        NSWorkspace.shared.open(video.webpageURL)
    }

    func openFullscreen(_ playback: PlaybackItem) {
        playbackController.load(playback, autoplay: playbackController.isPlaying)
        fullscreenPresenter.present(video: playback.video, player: playbackController.player)
    }

    func toggleFullscreen() {
        if fullscreenPresenter.isPresented {
            fullscreenPresenter.close()
        } else if let currentPlayback {
            openFullscreen(currentPlayback)
        }
    }

    func closePlayer() {
        playbackController.stop()
        fullscreenPresenter.close()
        currentPlayback = nil
        selectedVideo = nil
    }

    func chooseYTDLPBinary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose yt-dlp"
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            ytDlpPath = url.path
        }
    }

    func autoDetectYTDLP() {
        ytDlpPath = ""
        refreshHelperStatus()
    }

    func refreshHelperStatus() {
        helperStatus = .checking

        Task {
            let service = currentService()
            guard let path = service.resolvedPath else {
                helperStatus = .missing
                return
            }

            do {
                let version = try await service.version()
                helperStatus = .available(path: path, version: version)
            } catch {
                helperStatus = .failed(error.localizedDescription)
            }
        }
    }

    func clearCompletedJobs() {
        jobs.removeAll { job in
            if case .complete = job.status {
                return true
            }
            return false
        }
    }

    func deleteDownloadedFile(for job: DownloadJob) {
        guard case .complete(let url) = job.status else {
            return
        }

        try? FileManager.default.removeItem(at: url)
        jobs.removeAll { $0.id == job.id }

        if currentPlayback?.fileURL == url {
            playbackController.stop()
            currentPlayback = nil
            publishRemoteState()
        }
    }

    func setRemoteServerStatus(_ status: RemoteServerStatus) {
        remoteServerStatus = status
    }

    func enableRemoteControl() {
        guard !remoteServerStatus.isEnabled, !remoteServerStatus.isStarting else {
            return
        }

        remoteServerStatus.isStarting = true
        remoteServerStatus.errorMessage = nil

        Task {
            do {
                let server = RemoteControlServer(appModel: self)
                let status = try await server.start(port: RemoteControlDefaults.port)
                remoteServer = server
                remoteServerStatus = status
            } catch {
                remoteServer = nil
                remoteServerStatus = RemoteServerStatus(
                    isEnabled: false,
                    isStarting: false,
                    port: RemoteControlDefaults.port,
                    token: nil,
                    localURLs: [],
                    connectedClients: 0,
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    func disableRemoteControl() {
        let server = remoteServer
        remoteServer = nil
        remoteServerStatus = RemoteServerStatus(port: RemoteControlDefaults.port)

        Task {
            await server?.stop()
        }
    }

    func regenerateRemotePairingCode() {
        let server = remoteServer
        remoteServer = nil
        remoteServerStatus = RemoteServerStatus(
            isEnabled: false,
            isStarting: true,
            port: RemoteControlDefaults.port,
            token: nil,
            localURLs: [],
            connectedClients: 0,
            errorMessage: nil
        )

        Task {
            await server?.stop()
            remoteServerStatus = RemoteServerStatus(port: RemoteControlDefaults.port)
            enableRemoteControl()
        }
    }

    func remoteStateSnapshot() -> RemotePlaybackState {
        guard let playback = currentPlayback else {
            return .empty(
                selectedQuality: downloadQuality,
                volume: Double(playbackController.volume)
            )
        }

        let job = jobs.first { $0.video.id == playback.video.id }
        let playerDuration = playbackController.duration
        let fallbackDuration = playback.video.durationSeconds.map(Double.init) ?? 0
        let duration = playerDuration > 0 ? playerDuration : fallbackDuration

        return RemotePlaybackState(
            appName: "YT No Ads",
            hasVideo: true,
            title: playback.video.title,
            channel: playback.video.channelTitle,
            thumbnailURL: playback.video.thumbnailURL,
            webpageURL: playback.video.webpageURL,
            isPlaying: playbackController.isPlaying,
            isBuffering: playbackController.isBuffering,
            currentTime: playbackController.currentTime,
            duration: duration,
            volume: Double(playbackController.volume),
            selectedQuality: downloadQuality,
            sourceKind: RemotePlaybackSourceKind(playback.sourceKind),
            downloadState: job.map(RemoteDownloadState.init),
            availableQualities: DownloadQuality.allCases.map(RemoteQualityOption.init)
        )
    }

    func handleRemoteCommand(_ command: RemoteControlCommand) -> RemotePlaybackState {
        switch command.command {
        case .play:
            playbackController.play()
        case .pause:
            playbackController.pause()
        case .togglePlayPause:
            playbackController.togglePlayPause()
        case .seekBy:
            playbackController.seek(by: command.seconds ?? 0)
        case .seekTo:
            playbackController.seek(to: command.seconds ?? 0)
        case .setVolume:
            playbackController.setVolume(Float(command.volume ?? Double(playbackController.volume)))
        case .setQuality:
            if let quality = command.quality {
                downloadQuality = quality
            }
        case .toggleFullscreen:
            toggleFullscreen()
        case .closePlayer:
            closePlayer()
        }

        publishRemoteState()
        return remoteStateSnapshot()
    }

    func publishRemoteState() {
        if let remoteServer {
            let state = remoteStateSnapshot()
            Task {
                await remoteServer.publish(state)
            }
        }
    }

    private func start(jobID: UUID) {
        guard let job = jobs.first(where: { $0.id == jobID }) else {
            return
        }

        update(jobID: jobID) {
            $0.status = .running
            $0.detail = "Starting yt-dlp (\(job.quality.title))"
        }
        publishRemoteState()

        Task {
            let quality = job.quality
            let service = currentService()

            startPreviewStreamIfPossible(
                for: job,
                quality: quality,
                service: service
            )

            do {
                let manager = DownloadManager(
                    service: service,
                    cacheDirectory: cacheDirectory,
                    quality: quality
                )
                let fileURL = try await manager.download(video: job.video) { [weak self] progress in
                    Task { @MainActor in
                        guard let self else { return }

                        self.update(jobID: jobID) {
                            $0.progress = progress.fraction
                            $0.detail = progress.detail
                        }

                        if let fileURL = progress.fileURL,
                           self.selectedVideo?.id == job.video.id,
                           self.currentPlayback?.fileURL != fileURL {
                            self.currentPlayback = PlaybackItem(
                                video: job.video,
                                fileURL: fileURL,
                                sourceKind: .final(quality: quality)
                            )
                        }
                        self.publishRemoteState()
                    }
                }

                update(jobID: jobID) {
                    $0.status = .complete(fileURL)
                    $0.progress = 1
                    $0.detail = "Ready"
                    $0.completedAt = Date()
                }
                publishRemoteState()

                if selectedVideo?.id == job.video.id {
                    currentPlayback = PlaybackItem(
                        video: job.video,
                        fileURL: fileURL,
                        sourceKind: .final(quality: quality)
                    )
                    publishRemoteState()
                }
            } catch {
                update(jobID: jobID) {
                    $0.status = .failed(error.localizedDescription)
                    $0.detail = "Failed"
                }
                publishRemoteState()

                if currentPlayback?.video.id == job.video.id {
                    playbackController.stop()
                    currentPlayback = nil
                    publishRemoteState()
                }
            }
        }
    }

    private func update(jobID: UUID, mutate: (inout DownloadJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else {
            return
        }

        mutate(&jobs[index])
    }

    private func observePlaybackForRemoteState() {
        playbackStateCancellable = playbackController.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.publishRemoteState()
            }
        }
    }

    private func startPreviewStreamIfPossible(
        for job: DownloadJob,
        quality: DownloadQuality,
        service: YTDLPService
    ) {
        let previewQuality: DownloadQuality

        switch quality {
        case .fastStart, .hd720:
            previewQuality = quality
        case .best:
            previewQuality = .fastStart
        }

        Task {
            do {
                let streamURL = try await service.streamURL(
                    video: job.video,
                    quality: previewQuality
                )

                guard selectedVideo?.id == job.video.id else {
                    return
                }

                currentPlayback = PlaybackItem(
                    video: job.video,
                    fileURL: streamURL,
                    sourceKind: .preview(targetQuality: quality)
                )
                publishRemoteState()
                update(jobID: job.id) {
                    if quality == .best {
                        $0.detail = "Preview streaming, best download running"
                    } else {
                        $0.detail = "Streaming, download running"
                    }
                }
                publishRemoteState()
            } catch {
                update(jobID: job.id) {
                    $0.detail = "Resolving stream failed, downloading file"
                }
                publishRemoteState()
            }
        }
    }

    private func currentService() -> YTDLPService {
        YTDLPService(preferredPath: ytDlpPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ytDlpPath)
    }

    private static func defaultCacheDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let directory = base.appendingPathComponent("YTNoAds", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
