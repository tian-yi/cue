import Foundation

struct VideoSummary: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let channelTitle: String
    let durationSeconds: Int?
    let webpageURL: URL
    let thumbnailURL: URL?
    let viewCount: Int?

    var displayDuration: String {
        guard let durationSeconds else {
            return "--:--"
        }

        return DurationFormatter.clockString(from: durationSeconds)
    }
}

