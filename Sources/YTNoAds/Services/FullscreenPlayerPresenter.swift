import AppKit
import AVKit

@MainActor
final class FullscreenPlayerPresenter: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var player: AVPlayer?
    private var bufferMonitor: Timer?
    private var bufferingOverlay: NSView?

    func present(video: VideoSummary, fileURL: URL) {
        close()

        let item = AVPlayerItem(url: fileURL)
        item.preferredForwardBufferDuration = 8

        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true

        let playerView = AVPlayerView(frame: .zero)
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.showsFullScreenToggleButton = true
        playerView.allowsPictureInPicturePlayback = true
        playerView.player = player

        let contentView = NSView(frame: .zero)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor
        playerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playerView)

        let overlay = makeBufferingOverlay()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlay)

        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            overlay.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = video.title
        window.contentView = contentView
        window.collectionBehavior = [.fullScreenPrimary]
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
        self.player = player
        self.bufferingOverlay = overlay

        NSApp.activate(ignoringOtherApps: true)
        window.toggleFullScreen(nil)
        startBufferMonitor()
        player.play()
    }

    func close() {
        bufferMonitor?.invalidate()
        bufferMonitor = nil
        player?.pause()
        player = nil
        bufferingOverlay = nil
        window?.delegate = nil
        window?.close()
        window = nil
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            bufferMonitor?.invalidate()
            bufferMonitor = nil
            player?.pause()
            player = nil
            bufferingOverlay = nil
            window = nil
        }
    }

    private func makeBufferingOverlay() -> NSView {
        let container = NSVisualEffectView(frame: .zero)
        container.material = .hudWindow
        container.blendingMode = .withinWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.isHidden = true

        let progress = NSProgressIndicator(frame: .zero)
        progress.style = .spinning
        progress.controlSize = .small
        progress.startAnimation(nil)

        let label = NSTextField(labelWithString: "Buffering")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor

        let stack = NSStackView(views: [progress, label])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
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
            bufferingOverlay?.isHidden = true
            return
        }

        let item = player.currentItem
        let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        let notReady = item?.status == .unknown
        let bufferEmpty = item?.isPlaybackBufferEmpty ?? false
        let likelyToKeepUp = item?.isPlaybackLikelyToKeepUp ?? true

        bufferingOverlay?.isHidden = !(waiting || notReady || (bufferEmpty && !likelyToKeepUp))
    }
}
