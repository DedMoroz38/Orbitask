import Foundation

enum Formatters {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = .current
        return f
    }()
}
