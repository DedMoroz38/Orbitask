import Foundation

enum TaskPriority: Int, Codable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var colorHex: String {
        switch self {
        case .low: return "#4CAF50"       // green
        case .medium: return "#FF9800"    // orange
        case .high: return "#F44336"      // red
        case .critical: return "#9C27B0"  // purple
        }
    }

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct CosmicTask: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var priority: TaskPriority
    var dueDate: Date
    var link: String
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        priority: TaskPriority = .medium,
        dueDate: Date,
        link: String = "",
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.dueDate = dueDate
        self.link = link
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    /// Returns a value from 0.0 (far away — due date is far) to 1.0 (impact — due now or overdue).
    /// Tasks due within the next `horizonSeconds` are mapped linearly.
    func urgency(horizon: TimeInterval = 7 * 24 * 3600) -> Double {
        let now = Date()
        let remaining = dueDate.timeIntervalSince(now)
        if remaining <= 0 { return 1.0 }
        if remaining >= horizon { return 0.0 }
        return 1.0 - (remaining / horizon)
    }
}
