import Foundation

enum YTDLPError: LocalizedError {
    case binaryMissing
    case processFailed(arguments: [String], stderr: String)
    case invalidSearchResponse
    case missingStreamURL
    case missingDownloadedFile

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            return "yt-dlp was not found."
        case .processFailed(let arguments, let stderr):
            let command = (["yt-dlp"] + arguments).joined(separator: " ")
            return "\(command)\n\(stderr)"
        case .invalidSearchResponse:
            return "yt-dlp returned search data the app could not read."
        case .missingStreamURL:
            return "yt-dlp did not return a playable stream URL."
        case .missingDownloadedFile:
            return "yt-dlp finished without reporting a playable file."
        }
    }
}

struct YTDLPService {
    var preferredPath: String?

    var resolvedPath: String? {
        Self.resolveBinaryPath(preferredPath: preferredPath)
    }

    static func resolveBinaryPath(preferredPath: String?) -> String? {
        let fileManager = FileManager.default

        if let preferredPath,
           !preferredPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           fileManager.isExecutableFile(atPath: preferredPath) {
            return preferredPath
        }

        for path in ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp"] where fileManager.isExecutableFile(atPath: path) {
            return path
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["yt-dlp"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let path, fileManager.isExecutableFile(atPath: path) {
                return path
            }
        } catch {
            return nil
        }

        return nil
    }

    func version() async throws -> String {
        let result = try await run(arguments: ["--version"])
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func search(query: String, limit: Int = 20) async throws -> [VideoSummary] {
        let searchArgument = "ytsearch\(limit):\(query)"
        let result = try await run(arguments: [
            "--dump-single-json",
            "--flat-playlist",
            "--no-warnings",
            searchArgument
        ])

        guard let data = result.stdout.data(using: .utf8) else {
            throw YTDLPError.invalidSearchResponse
        }

        return try Self.decodeSearchResults(from: data)
    }

    func streamURL(video: VideoSummary, quality: DownloadQuality) async throws -> URL {
        let result = try await run(arguments: [
            "--no-playlist",
            "--no-warnings",
            "-f",
            quality.formatSelector,
            "--get-url",
            video.webpageURL.absoluteString
        ])

        guard let urlString = result.stdout
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { $0.hasPrefix("http://") || $0.hasPrefix("https://") }),
              let url = URL(string: urlString) else {
            throw YTDLPError.missingStreamURL
        }

        return url
    }

    func download(
        video: VideoSummary,
        outputDirectory: URL,
        quality: DownloadQuality,
        progress: @escaping (DownloadProgress) -> Void
    ) async throws -> URL {
        let outputTemplate = outputDirectory
            .appendingPathComponent("%(title).120B [%(id)s].%(ext)s")
            .path

        let result = try await run(arguments: [
            "--newline",
            "--no-playlist",
            "--restrict-filenames"
        ] + quality.ytDlpArguments + [
            "--print",
            "after_move:filepath",
            "-o",
            outputTemplate,
            video.webpageURL.absoluteString
        ]) { line in
            if var parsed = Self.parseProgress(line: line) {
                if quality.supportsProgressivePlayback {
                    parsed.fileURL = Self.activePlaybackFile(in: outputDirectory)
                }
                progress(parsed)
            }
        }

        if let reportedPath = result.stdout
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .last(where: { !$0.hasPrefix("[") && FileManager.default.fileExists(atPath: $0) }) {
            return URL(fileURLWithPath: reportedPath)
        }

        if let discovered = try discoverDownloadedFile(in: outputDirectory) {
            return discovered
        }

        throw YTDLPError.missingDownloadedFile
    }

    private func discoverDownloadedFile(in directory: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        return contents.first { url in
            let path = url.path
            return !path.hasSuffix(".part") && !path.hasSuffix(".ytdl")
        }
    }

    private static func activePlaybackFile(in directory: URL) -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return nil
        }

        return contents
            .filter { url in
                let path = url.path
                return !path.hasSuffix(".ytdl") && !path.hasSuffix(".json")
            }
            .compactMap { url -> (URL, Int)? in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values?.isRegularFile == true,
                      let size = values?.fileSize,
                      size >= 256 * 1024 else {
                    return nil
                }
                return (url, size)
            }
            .sorted { lhs, rhs in
                if lhs.0.pathExtension == "mp4", rhs.0.pathExtension != "mp4" {
                    return true
                }
                return lhs.1 > rhs.1
            }
            .first?
            .0
    }

    private func run(
        arguments: [String],
        lineHandler: ((String) -> Void)? = nil
    ) async throws -> ProcessResult {
        guard let binaryPath = resolvedPath else {
            throw YTDLPError.binaryMissing
        }

        let processBox = RunningProcessBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let queue = DispatchQueue(label: "app.ytnoads.ytdlp.output")
            var stdout = Data()
            var stderr = Data()
            var stdoutRemainder = ""
            var stderrRemainder = ""
            var didResume = false

            func emitLines(from text: String, remainder: inout String) {
                remainder += text
                let lines = remainder.split(separator: "\n", omittingEmptySubsequences: false)
                guard !lines.isEmpty else { return }

                for line in lines.dropLast() {
                    lineHandler?(String(line).trimmingCharacters(in: .whitespacesAndNewlines))
                }

                remainder = String(lines.last ?? "")
            }

            func resumeOnce(_ result: Result<ProcessResult, Error>) {
                queue.async {
                    guard !didResume else { return }
                    didResume = true
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    if !stdoutRemainder.isEmpty {
                        lineHandler?(stdoutRemainder.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    if !stderrRemainder.isEmpty {
                        lineHandler?(stderrRemainder.trimmingCharacters(in: .whitespacesAndNewlines))
                    }

                    continuation.resume(with: result)
                }
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                queue.async {
                    stdout.append(data)
                    if let text = String(data: data, encoding: .utf8) {
                        emitLines(from: text, remainder: &stdoutRemainder)
                    }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                queue.async {
                    stderr.append(data)
                    if let text = String(data: data, encoding: .utf8) {
                        emitLines(from: text, remainder: &stderrRemainder)
                    }
                }
            }

            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            processBox.set(process)
            process.terminationHandler = { finishedProcess in
                queue.asyncAfter(deadline: .now() + 0.05) {
                    let result = ProcessResult(
                        terminationStatus: finishedProcess.terminationStatus,
                        stdout: String(data: stdout, encoding: .utf8) ?? "",
                        stderr: String(data: stderr, encoding: .utf8) ?? ""
                    )

                    if finishedProcess.terminationStatus == 0 {
                        resumeOnce(.success(result))
                    } else {
                        resumeOnce(.failure(YTDLPError.processFailed(arguments: arguments, stderr: result.stderr)))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                resumeOnce(.failure(error))
            }
        }
        } onCancel: {
            processBox.terminate()
        }
    }

    static func decodeSearchResults(from data: Data) throws -> [VideoSummary] {
        do {
            let response = try JSONDecoder().decode(YTDLPSearchResponse.self, from: data)
            return response.entries.compactMap { $0.videoSummary }
        } catch {
            throw YTDLPError.invalidSearchResponse
        }
    }

    static func parseProgress(line: String) -> DownloadProgress? {
        guard line.contains("[download]") else {
            return nil
        }

        let pieces = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let percentPiece = pieces.first(where: { $0.hasSuffix("%") }) else {
            return nil
        }

        let number = percentPiece
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let percent = Double(number) else {
            return nil
        }

        return DownloadProgress(
            fraction: min(max(percent / 100, 0), 1),
            detail: line.replacingOccurrences(of: "[download]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            fileURL: nil,
            isFinalFile: true
        )
    }
}

private struct ProcessResult {
    let terminationStatus: Int32
    let stdout: String
    let stderr: String
}

private final class RunningProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?

    func set(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    func terminate() {
        lock.lock()
        let process = process
        lock.unlock()

        if process?.isRunning == true {
            process?.terminate()
        }
    }
}

private struct YTDLPSearchResponse: Decodable {
    let entries: [YTDLPEntry]
}

private struct YTDLPEntry: Decodable {
    let id: String?
    let title: String?
    let url: String?
    let webpageURL: String?
    let ieKey: String?
    let channel: String?
    let uploader: String?
    let duration: Double?
    let viewCount: Int?
    let thumbnails: [YTDLPThumbnail]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case webpageURL = "webpage_url"
        case ieKey = "ie_key"
        case channel
        case uploader
        case duration
        case viewCount = "view_count"
        case thumbnails
    }

    var videoSummary: VideoSummary? {
        guard let id, let title else {
            return nil
        }
        guard id.count == 11, ieKey != "YoutubeTab" else {
            return nil
        }

        let watchURL: URL
        if let webpageURL, let parsed = URL(string: webpageURL) {
            watchURL = parsed
        } else if let url, url.hasPrefix("http"), let parsed = URL(string: url) {
            watchURL = parsed
        } else {
            watchURL = URL(string: "https://www.youtube.com/watch?v=\(id)")!
        }

        let thumbnail = thumbnails?
            .compactMap(\.resolvedURL)
            .last ?? URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")

        return VideoSummary(
            id: id,
            title: title,
            channelTitle: channel ?? uploader ?? "YouTube",
            durationSeconds: duration.map(Int.init),
            webpageURL: watchURL,
            thumbnailURL: thumbnail,
            viewCount: viewCount
        )
    }
}

private struct YTDLPThumbnail: Decodable {
    let url: String?

    var resolvedURL: URL? {
        guard let url else { return nil }
        if url.hasPrefix("//") {
            return URL(string: "https:\(url)")
        }
        return URL(string: url)
    }
}
