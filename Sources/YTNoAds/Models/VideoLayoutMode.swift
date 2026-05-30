import Foundation

enum VideoLayoutMode: String, CaseIterable, Identifiable {
    case gallery
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gallery:
            return "Gallery"
        case .list:
            return "List"
        }
    }

    var systemImage: String {
        switch self {
        case .gallery:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}

