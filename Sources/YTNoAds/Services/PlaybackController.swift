import AVFoundation
import Foundation

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var volume: Float

    let player: AVPlayer

    private static let volumeKey = "playerVolume"
    private var currentURL: URL?
    private var currentPlaybackID: UUID?
    private var timeObserver: Any?
    private var bufferMonitor: Timer?

    init() {
        self.volume = UserDefaults.standard.object(forKey: Self.volumeKey) as? Float ?? 0.8
        self.player = AVPlayer()
        self.player.volume = volume
        self.player.automaticallyWaitsToMinimizeStalling = true
        startTimeObserver()
        startBufferMonitor()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        bufferMonitor?.invalidate()
    }

    func load(_ playback: PlaybackItem, autoplay: Bool = true) {
        guard currentPlaybackID != playback.id || currentURL != playback.fileURL else {
            return
        }

        let item = AVPlayerItem(url: playback.fileURL)
        item.preferredForwardBufferDuration = 8
        player.replaceCurrentItem(with: item)
        currentPlaybackID = playback.id
        currentURL = playback.fileURL
        currentTime = 0
        duration = playback.video.durationSeconds.map(TimeInterval.init) ?? 0
        isBuffering = true

        if autoplay {
            play()
        } else {
            pause()
        }
    }

    func play() {
        player.play()
        refreshSnapshot()
    }

    func pause() {
        player.pause()
        refreshSnapshot()
    }

    func togglePlayPause() {
        if isPlaying || player.rate > 0 {
            pause()
        } else {
            play()
        }
    }

    func seek(by delta: TimeInterval) {
        seek(to: currentTime + delta)
    }

    func seek(to seconds: TimeInterval) {
        let bounded: TimeInterval
        if duration > 0 {
            bounded = min(max(seconds, 0), duration)
        } else {
            bounded = max(seconds, 0)
        }

        player.seek(
            to: CMTime(seconds: bounded, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        currentTime = bounded
    }

    func setVolume(_ newVolume: Float) {
        let bounded = min(max(newVolume, 0), 1)
        volume = bounded
        player.volume = bounded
        UserDefaults.standard.set(bounded, forKey: Self.volumeKey)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentURL = nil
        currentPlaybackID = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        isBuffering = false
    }

    private func startTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSnapshot()
            }
        }
    }

    private func startBufferMonitor() {
        bufferMonitor?.invalidate()
        bufferMonitor = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSnapshot()
            }
        }
    }

    private func refreshSnapshot() {
        update(&isPlaying, to: player.rate > 0 || player.timeControlStatus == .playing)
        update(&currentTime, to: player.currentTime().seconds.finiteOrZero, tolerance: 0.05)

        if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
            update(&duration, to: itemDuration, tolerance: 0.05)
        }

        let item = player.currentItem
        let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        let notReady = item?.status == .unknown
        let bufferEmpty = item?.isPlaybackBufferEmpty ?? false
        let likelyToKeepUp = item?.isPlaybackLikelyToKeepUp ?? true

        update(&isBuffering, to: waiting || notReady || (bufferEmpty && !likelyToKeepUp))
    }

    private func update(_ value: inout Bool, to newValue: Bool) {
        if value != newValue {
            value = newValue
        }
    }

    private func update(_ value: inout TimeInterval, to newValue: TimeInterval, tolerance: TimeInterval) {
        if abs(value - newValue) > tolerance {
            value = newValue
        }
    }
}

private extension Double {
    var finiteOrZero: Double {
        isFinite ? self : 0
    }
}
