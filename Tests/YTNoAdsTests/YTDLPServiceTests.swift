import XCTest
@testable import YTNoAds

final class YTDLPServiceTests: XCTestCase {
    func testDecodeSearchResultsKeepsOnlyVideos() throws {
        let json = """
        {
          "entries": [
            {
              "_type": "url",
              "url": "https://www.youtube.com/channel/UCXZCJLdBC09xxGZ6gcdrc6A",
              "id": "UCXZCJLdBC09xxGZ6gcdrc6A",
              "ie_key": "YoutubeTab",
              "title": "OpenAI",
              "channel": "OpenAI"
            },
            {
              "_type": "url",
              "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
              "id": "dQw4w9WgXcQ",
              "ie_key": "Youtube",
              "title": "Demo Video",
              "channel": "Demo Channel",
              "duration": 213,
              "view_count": 1000,
              "thumbnails": [
                { "url": "//i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg" }
              ]
            }
          ]
        }
        """

        let videos = try YTDLPService.decodeSearchResults(from: Data(json.utf8))

        XCTAssertEqual(videos.count, 1)
        XCTAssertEqual(videos.first?.id, "dQw4w9WgXcQ")
        XCTAssertEqual(videos.first?.title, "Demo Video")
        XCTAssertEqual(videos.first?.channelTitle, "Demo Channel")
        XCTAssertEqual(videos.first?.durationSeconds, 213)
        XCTAssertEqual(videos.first?.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
    }

    func testParseProgressLine() {
        let progress = YTDLPService.parseProgress(
            line: "[download]  42.7% of 10.00MiB at 1.20MiB/s ETA 00:05"
        )

        XCTAssertEqual(progress?.fraction ?? 0, 0.427, accuracy: 0.001)
        XCTAssertEqual(progress?.detail, "42.7% of 10.00MiB at 1.20MiB/s ETA 00:05")
        XCTAssertEqual(progress?.isFinalFile, true)
    }

    func testDownloadQualitySelectors() {
        XCTAssertEqual(
            DownloadQuality.fastStart.formatSelector,
            "best[ext=mp4][protocol=https]/best[protocol=https]/best[ext=mp4]/best"
        )
        XCTAssertTrue(DownloadQuality.fastStart.supportsProgressivePlayback)
        XCTAssertTrue(DownloadQuality.hd720.supportsProgressivePlayback)
        XCTAssertFalse(DownloadQuality.best.supportsProgressivePlayback)
        XCTAssertTrue(DownloadQuality.best.ytDlpArguments.contains("--merge-output-format"))
    }

    func testStreamURLResolverReturnsDirectMediaURL() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("YTNoAdsTests-\(UUID().uuidString)", isDirectory: true)
        let fakeBinary = root.appendingPathComponent("yt-dlp")

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let script = """
        #!/usr/bin/env bash
        set -euo pipefail

        for arg in "$@"; do
          if [[ "$arg" == "--get-url" ]]; then
            echo "https://media.example.test/preview.mp4"
            exit 0
          fi
        done

        exit 1
        """

        try script.write(to: fakeBinary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fakeBinary.path
        )

        let service = YTDLPService(preferredPath: fakeBinary.path)
        let video = VideoSummary(
            id: "abc123DEF45",
            title: "Fake Video",
            channelTitle: "Tests",
            durationSeconds: nil,
            webpageURL: URL(string: "https://www.youtube.com/watch?v=abc123DEF45")!,
            thumbnailURL: nil,
            viewCount: nil
        )

        let streamURL = try await service.streamURL(video: video, quality: .fastStart)

        XCTAssertEqual(streamURL.absoluteString, "https://media.example.test/preview.mp4")
    }

    func testDownloadManagerMovesCompletedHelperOutput() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("YTNoAdsTests-\(UUID().uuidString)", isDirectory: true)
        let fakeBinary = root.appendingPathComponent("yt-dlp")

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let script = """
        #!/usr/bin/env bash
        set -euo pipefail

        if [[ "${1:-}" == "--version" ]]; then
          echo "test-version"
          exit 0
        fi

        for arg in "$@"; do
          if [[ "$arg" == "--dump-single-json" ]]; then
            echo '{"entries":[{"id":"abc123DEF45","ie_key":"Youtube","title":"Fake Video","channel":"Tests","url":"https://www.youtube.com/watch?v=abc123DEF45"}]}'
            exit 0
          fi
        done

        output_template=""
        previous=""
        for arg in "$@"; do
          if [[ "$previous" == "-o" ]]; then
            output_template="$arg"
          fi
          previous="$arg"
        done

        output_dir="$(dirname "$output_template")"
        output_path="$output_dir/Fake_Video_abc123DEF45.mp4"
        dd if=/dev/zero of="$output_path" bs=1024 count=300 >/dev/null 2>&1
        echo "[download]  50.0% of 1.00MiB at 1.00MiB/s ETA 00:01"
        echo "$output_path"
        """

        try script.write(to: fakeBinary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fakeBinary.path
        )

        let service = YTDLPService(preferredPath: fakeBinary.path)
        let manager = DownloadManager(
            service: service,
            cacheDirectory: root,
            quality: .fastStart
        )
        let video = VideoSummary(
            id: "abc123DEF45",
            title: "Fake Video",
            channelTitle: "Tests",
            durationSeconds: nil,
            webpageURL: URL(string: "https://www.youtube.com/watch?v=abc123DEF45")!,
            thumbnailURL: nil,
            viewCount: nil
        )
        var progressFractions: [Double] = []
        var progressivePlaybackURLs: [URL] = []

        let downloaded = try await manager.download(video: video) { progress in
            progressFractions.append(progress.fraction)
            if let fileURL = progress.fileURL {
                progressivePlaybackURLs.append(fileURL)
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: downloaded.path))
        XCTAssertTrue(downloaded.path.contains("/Downloads/"))
        XCTAssertEqual(progressFractions.last ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(progressivePlaybackURLs.count, 1)
        XCTAssertEqual(progressivePlaybackURLs.first?.lastPathComponent, "Fake_Video_abc123DEF45.mp4")
    }

    func testBestQualityReturnsFinalFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("YTNoAdsTests-\(UUID().uuidString)", isDirectory: true)
        let fakeBinary = root.appendingPathComponent("yt-dlp")

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let script = """
        #!/usr/bin/env bash
        set -euo pipefail

        output_template=""
        previous=""
        is_best="false"

        for arg in "$@"; do
          if [[ "$arg" == "--merge-output-format" ]]; then
            is_best="true"
          fi
          if [[ "$previous" == "-o" ]]; then
            output_template="$arg"
          fi
          previous="$arg"
        done

        output_dir="$(dirname "$output_template")"

        if [[ "$is_best" != "true" ]]; then
          echo "expected best mode" >&2
          exit 1
        fi

        output_path="$output_dir/Final_Best_abc123DEF45.mp4"
        dd if=/dev/zero of="$output_path" bs=1024 count=300 >/dev/null 2>&1
        echo "[download]  70.0% of 1.00MiB at 1.00MiB/s ETA 00:01"
        echo "$output_path"
        """

        try script.write(to: fakeBinary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fakeBinary.path
        )

        let service = YTDLPService(preferredPath: fakeBinary.path)
        let manager = DownloadManager(
            service: service,
            cacheDirectory: root,
            quality: .best
        )
        let video = VideoSummary(
            id: "abc123DEF45",
            title: "Fake Video",
            channelTitle: "Tests",
            durationSeconds: nil,
            webpageURL: URL(string: "https://www.youtube.com/watch?v=abc123DEF45")!,
            thumbnailURL: nil,
            viewCount: nil
        )
        var finalProgressSeen = false

        let downloaded = try await manager.download(video: video) { progress in
            if progress.isFinalFile {
                finalProgressSeen = true
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: downloaded.path))
        XCTAssertEqual(downloaded.lastPathComponent, "Final_Best_abc123DEF45.mp4")
        XCTAssertTrue(finalProgressSeen)
    }
}
