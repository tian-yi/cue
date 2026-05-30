import Foundation

enum AppFormatters {
    static func compactCount(_ value: Int?) -> String {
        guard let value else {
            return ""
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

