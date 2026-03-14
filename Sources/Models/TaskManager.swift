import Foundation

/// Persists tasks to a JSON file in Application Support and provides CRUD operations.
class TaskManager: ObservableObject {
    static let shared = TaskManager()

    @Published private(set) var tasks: [CosmicTask] = []

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CosmicTasks", isDirectory: true)

        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        fileURL = appDir.appendingPathComponent("tasks.json")
        load()
    }

    // MARK: - CRUD

    func add(_ task: CosmicTask) {
        tasks.append(task)
        save()
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    func update(_ task: CosmicTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        save()
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    func remove(_ taskID: UUID) {
        tasks.removeAll { $0.id == taskID }
        save()
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    func complete(_ taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].isCompleted = true
        save()
        NotificationCenter.default.post(name: .taskCompleted, object: taskID)
    }

    /// Returns only active (incomplete) tasks, sorted by urgency descending.
    var activeTasks: [CosmicTask] {
        tasks
            .filter { !$0.isCompleted }
            .sorted { $0.urgency() > $1.urgency() }
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            // Seed with demo tasks on first launch
            seedDemoTasks()
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([CosmicTask].self, from: data) {
            tasks = decoded
        }
    }

    private func seedDemoTasks() {
        let now = Date()
        let hour: TimeInterval = 3600
        let day: TimeInterval = hour * 24

        tasks = [
            CosmicTask(title: "Ship v2.0 release", description: "Final build, tag, and deploy to production", priority: .critical, dueDate: now.addingTimeInterval(3 * hour)),
            CosmicTask(title: "Code review PR #42", description: "Review authentication refactor", priority: .high, dueDate: now.addingTimeInterval(8 * hour)),
            CosmicTask(title: "Update API docs", description: "Document new endpoints for v2", priority: .medium, dueDate: now.addingTimeInterval(2 * day)),
            CosmicTask(title: "Design system audit", description: "Check component library for inconsistencies", priority: .low, dueDate: now.addingTimeInterval(5 * day)),
            CosmicTask(title: "Quarterly planning", description: "Prepare roadmap for Q3", priority: .medium, dueDate: now.addingTimeInterval(4 * day)),
            CosmicTask(title: "Fix memory leak", description: "Profile and fix the leak in image cache", priority: .high, dueDate: now.addingTimeInterval(12 * hour)),
        ]
        save()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let tasksDidChange = Notification.Name("tasksDidChange")
    static let taskCompleted = Notification.Name("taskCompleted")
}
