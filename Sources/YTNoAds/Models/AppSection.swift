import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case search
    case downloads
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search:
            return "Search"
        case .downloads:
            return "Downloads"
        case .library:
            return "Library"
        }
    }

    var systemImage: String {
        switch self {
        case .search:
            return "magnifyingglass"
        case .downloads:
            return "arrow.down.circle"
        case .library:
            return "play.rectangle.on.rectangle"
        }
    }
}

