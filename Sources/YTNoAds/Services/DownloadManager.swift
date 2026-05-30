import Foundation

struct DownloadProgress {
    var fraction: Double
    var detail: String
    var fileURL: URL?
    var isFinalFile: Bool
}

final class DownloadManager {
    private let service: YTDLPService
    private let cacheDirectory: URL
    private let quality: DownloadQuality

    init(service: YTDLPService, cacheDirectory: URL, quality: DownloadQuality) {
        self.service = service
        self.cacheDirectory = cacheDirectory
        self.quality = quality
    }

    func download(
        video: VideoSummary,
        progress: @escaping (DownloadProgress) -> Void
    ) async throws -> URL {
        let downloadsDirectory = cacheDirectory.appendingPathComponent("Downloads", isDirectory: true)
        let temporaryDirectory = cacheDirectory
            .appendingPathComponent("Incoming", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: downloadsDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let downloadedFile = try await service.download(
            video: video,
            outputDirectory: temporaryDirectory,
            quality: quality,
            progress: progress
        )

        let destination = uniqueDestination(
            for: downloadedFile.lastPathComponent,
            in: downloadsDirectory
        )
        try FileManager.default.moveItem(at: downloadedFile, to: destination)
        return destination
    }

    private func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        let base = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: fileName).pathExtension
        var candidate = directory.appendingPathComponent(fileName)
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
            candidate = directory.appendingPathComponent(name)
            suffix += 1
        }

        return candidate
    }
}
