import Foundation

enum HelperStatus: Equatable {
    case checking
    case available(path: String, version: String)
    case missing
    case failed(String)

    var title: String {
        switch self {
        case .checking:
            return "Checking yt-dlp"
        case .available(_, let version):
            return "yt-dlp \(version)"
        case .missing:
            return "yt-dlp not found"
        case .failed:
            return "yt-dlp unavailable"
        }
    }

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
}

