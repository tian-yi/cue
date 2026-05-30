import XCTest
@testable import Cue

final class RemoteControlModelsTests: XCTestCase {
    func testRemoteControlCommandCodableRoundTripsPayloads() throws {
        let command = RemoteControlCommand(
            command: .setQuality,
            seconds: 42.5,
            volume: 0.75,
            quality: .hd720
        )

        let encoded = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(RemoteControlCommand.self, from: encoded)

        XCTAssertEqual(decoded, command)
    }

    func testRemoteControlCommandDecodesExpectedJSONShape() throws {
        let json = """
        {
          "command": "seekBy",
          "seconds": -15,
          "volume": null,
          "quality": "fastStart"
        }
        """

        let decoded = try JSONDecoder().decode(RemoteControlCommand.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.command, .seekBy)
        XCTAssertEqual(decoded.seconds, -15)
        XCTAssertNil(decoded.volume)
        XCTAssertEqual(decoded.quality, .fastStart)
    }

    func testEmptyRemotePlaybackStateHasNoVideoAndAllQualities() {
        let state = RemotePlaybackState.empty(
            selectedQuality: .best,
            volume: 0.4
        )

        XCTAssertEqual(state.appName, "Cue")
        XCTAssertFalse(state.hasVideo)
        XCTAssertNil(state.title)
        XCTAssertNil(state.channel)
        XCTAssertNil(state.thumbnailURL)
        XCTAssertNil(state.webpageURL)
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isBuffering)
        XCTAssertEqual(state.currentTime, 0)
        XCTAssertEqual(state.duration, 0)
        XCTAssertEqual(state.volume, 0.4)
        XCTAssertEqual(state.selectedQuality, .best)
        XCTAssertNil(state.sourceKind)
        XCTAssertNil(state.downloadState)
        XCTAssertEqual(state.availableQualities.map(\.id), DownloadQuality.allCases)
    }

    func testRemotePlaybackSourceKindMapsPreviewSource() {
        let source = RemotePlaybackSourceKind(.preview(targetQuality: .best))

        XCTAssertEqual(source.kind, "preview")
        XCTAssertEqual(source.title, "Preview quality")
        XCTAssertEqual(source.detail, "Best quality is downloading in the background.")
        XCTAssertNil(source.quality)
        XCTAssertEqual(source.targetQuality, .best)
    }

    func testRemotePlaybackSourceKindMapsFinalSource() {
        let source = RemotePlaybackSourceKind(.final(quality: .hd720))

        XCTAssertEqual(source.kind, "final")
        XCTAssertEqual(source.title, "720p ready")
        XCTAssertEqual(source.detail, "Playing from the completed download.")
        XCTAssertEqual(source.quality, .hd720)
        XCTAssertNil(source.targetQuality)
    }

    func testRemoteDownloadStateMapsStatuses() {
        XCTAssertEqual(remoteDownloadState(status: .queued).status, "queued")
        XCTAssertEqual(remoteDownloadState(status: .running).status, "running")
        XCTAssertEqual(remoteDownloadState(status: .complete(URL(fileURLWithPath: "/tmp/video.mp4"))).status, "complete")
        XCTAssertEqual(remoteDownloadState(status: .failed("Network unavailable")).status, "failed")
    }

    func testRemoteDownloadStatePreservesJobDetails() {
        let state = remoteDownloadState(status: .running, quality: .hd720)

        XCTAssertEqual(state.progress, 0.35)
        XCTAssertEqual(state.detail, "Downloading")
        XCTAssertEqual(state.quality, .hd720)
    }

    func testIPv4AddressResolverIsCallable() {
        XCTAssertNoThrow(_ = IPv4AddressResolver.localAddresses())
    }

    func testRemoteSearchModelsRoundTrip() throws {
        let request = RemoteSearchRequest(query: "ballet")
        let response = RemoteSearchResponse(results: [videoSummary()])
        let playRequest = RemotePlayRequest(videoID: "abc123DEF45")

        XCTAssertEqual(try JSONDecoder().decode(RemoteSearchRequest.self, from: JSONEncoder().encode(request)), request)
        XCTAssertEqual(try JSONDecoder().decode(RemoteSearchResponse.self, from: JSONEncoder().encode(response)), response)
        XCTAssertEqual(try JSONDecoder().decode(RemotePlayRequest.self, from: JSONEncoder().encode(playRequest)), playRequest)
    }

    private func remoteDownloadState(
        status: DownloadStatus,
        quality: DownloadQuality = .fastStart
    ) -> RemoteDownloadState {
        RemoteDownloadState(
            job: DownloadJob(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                video: videoSummary(),
                quality: quality,
                status: status,
                progress: 0.35,
                detail: "Downloading",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                completedAt: nil
            )
        )
    }

    private func videoSummary() -> VideoSummary {
        VideoSummary(
            id: "abc123DEF45",
            title: "Remote Test Video",
            channelTitle: "Tests",
            durationSeconds: 120,
            webpageURL: URL(string: "https://www.youtube.com/watch?v=abc123DEF45")!,
            thumbnailURL: URL(string: "https://i.ytimg.com/vi/abc123DEF45/hqdefault.jpg"),
            viewCount: 1_000
        )
    }
}
