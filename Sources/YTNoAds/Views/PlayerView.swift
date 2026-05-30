import AVKit
import SwiftUI

struct PlayerView: NSViewRepresentable {
    let fileURL: URL
    @Binding var isBuffering: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isBuffering: $isBuffering)
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.showsFullScreenToggleButton = true
        playerView.allowsPictureInPicturePlayback = true
        playerView.player = context.coordinator.player(for: fileURL)
        playerView.player?.play()
        return playerView
    }

    func updateNSView(_ playerView: AVPlayerView, context: Context) {
        context.coordinator.update(isBuffering: $isBuffering)
        playerView.player = context.coordinator.player(for: fileURL)
        playerView.player?.play()
    }

    static func dismantleNSView(_ playerView: AVPlayerView, coordinator: Coordinator) {
        playerView.player?.pause()
        playerView.player = nil
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var currentURL: URL?
        var player: AVPlayer?
        private var isBuffering: Binding<Bool>
        private var bufferMonitor: Timer?

        init(isBuffering: Binding<Bool>) {
            self.isBuffering = isBuffering
        }

        func update(isBuffering: Binding<Bool>) {
            self.isBuffering = isBuffering
        }

        func player(for url: URL) -> AVPlayer {
            if currentURL != url {
                player?.pause()
                player = Self.makePlayer(for: url)
                currentURL = url
                startBufferMonitor()
            }

            guard let player else {
                let newPlayer = Self.makePlayer(for: url)
                self.player = newPlayer
                currentURL = url
                startBufferMonitor()
                return newPlayer
            }

            return player
        }

        func stop() {
            bufferMonitor?.invalidate()
            bufferMonitor = nil
            player?.pause()
            player = nil
            currentURL = nil
            isBuffering.wrappedValue = false
        }

        private static func makePlayer(for url: URL) -> AVPlayer {
            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 8

            let player = AVPlayer(playerItem: item)
            player.automaticallyWaitsToMinimizeStalling = true
            return player
        }

        private func startBufferMonitor() {
            bufferMonitor?.invalidate()
            refreshBufferingState()
            bufferMonitor = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshBufferingState()
                }
            }
        }

        private func refreshBufferingState() {
            guard let player else {
                isBuffering.wrappedValue = false
                return
            }

            let item = player.currentItem
            let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            let notReady = item?.status == .unknown
            let bufferEmpty = item?.isPlaybackBufferEmpty ?? false
            let likelyToKeepUp = item?.isPlaybackLikelyToKeepUp ?? true

            isBuffering.wrappedValue = waiting || notReady || (bufferEmpty && !likelyToKeepUp)
        }
    }
}
