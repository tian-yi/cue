import Foundation

enum DownloadQuality: String, CaseIterable, Identifiable, Codable {
    case fastStart
    case hd720
    case best

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fastStart:
            return "Fast Start"
        case .hd720:
            return "720p"
        case .best:
            return "Best"
        }
    }

    var detail: String {
        switch self {
        case .fastStart:
            return "Starts playback as soon as possible."
        case .hd720:
            return "Prefers a single 720p stream when available."
        case .best:
            return "Streams a fast preview, then upgrades to the highest-quality merged file. May require ffmpeg."
        }
    }

    var formatSelector: String {
        switch self {
        case .fastStart:
            return "best[ext=mp4][protocol=https]/best[protocol=https]/best[ext=mp4]/best"
        case .hd720:
            return "best[height<=720][ext=mp4][protocol=https]/best[height<=720][protocol=https]/best[ext=mp4]/best"
        case .best:
            return "bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/best"
        }
    }

    var supportsProgressivePlayback: Bool {
        switch self {
        case .fastStart, .hd720:
            return true
        case .best:
            return false
        }
    }

    var ytDlpArguments: [String] {
        switch self {
        case .fastStart, .hd720:
            return [
                "--no-part",
                "-f",
                formatSelector
            ]
        case .best:
            return [
                "-f",
                formatSelector,
                "--merge-output-format",
                "mp4"
            ]
        }
    }
}
