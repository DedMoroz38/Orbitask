import Cocoa

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

    func delete(_ taskID: UUID) {
        remove(taskID)
    }

    func cyclePriority(_ taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let all = TaskPriority.allCases
        let current = tasks[index].priority
        let nextIndex = (all.firstIndex(of: current)! + 1) % all.count
        tasks[index].priority = all[nextIndex]
        save()
        NotificationCenter.default.post(name: .tasksDidChange, object: nil)
    }

    /// Returns only active (incomplete) tasks, sorted by urgency descending.
    var activeTasks: [CosmicTask] {
        tasks
            .filter { !$0.isCompleted }
            .sorted { $0.urgency() > $1.urgency() }
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(tasks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[TaskManager] save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            seedDemoTasks()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            tasks = try decoder.decode([CosmicTask].self, from: data)
        } catch {
            print("[TaskManager] load failed: \(error)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Could not load tasks"
                alert.informativeText = "Your tasks file could not be read and will be reset to defaults.\n\nError: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            seedDemoTasks()
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
    static let taskReceivedFromBackend = Notification.Name("taskReceivedFromBackend")
}
