import Cocoa
import SwiftUI

/// Controls the menu bar status item and provides task management UI.
class StatusBarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private weak var scene: CosmicScene?

    init(scene: CosmicScene) {
        self.scene = scene

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "CosmicTasks")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

// MARK: - SwiftUI Menu Bar View

struct MenuBarView: View {
    @ObservedObject private var taskManager = TaskManager.shared
    @State private var showingAddTask = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("Cosmic Tasks")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding()

            Divider()

            if taskManager.activeTasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "moon.stars")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No active tasks")
                        .foregroundColor(.secondary)
                    Text("All clear — the cosmos is at peace")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(taskManager.activeTasks) { task in
                            TaskRowView(task: task)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(taskManager.activeTasks.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 340, height: 480)
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(isPresented: $showingAddTask)
        }
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: CosmicTask

    private var urgencyLabel: String {
        let u = task.urgency()
        if u > 0.9 { return "IMPACT IMMINENT" }
        if u > 0.7 { return "Approaching fast" }
        if u > 0.4 { return "In orbit" }
        return "Distant"
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(task.priority.label)
                        .font(.system(size: 9))
                        .foregroundColor(priorityColor)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(urgencyLabel)
                        .font(.system(size: 9))
                        .foregroundColor(task.urgency() > 0.7 ? .red : .secondary)
                }
            }

            Spacer()

            // Complete button
            Button(action: {
                TaskManager.shared.complete(task.id)
            }) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: {
                TaskManager.shared.remove(task.id)
            }) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Add Task Sheet

struct AddTaskSheet: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var dueDate = Date().addingTimeInterval(24 * 3600)

    var body: some View {
        VStack(spacing: 16) {
            Text("New Task")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Task title", text: $title)
                    .textFieldStyle(.roundedBorder)

                TextField("Description (optional)", text: $description)
                    .textFieldStyle(.roundedBorder)

                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                DatePicker("Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Task") {
                    let task = CosmicTask(
                        title: title,
                        description: description,
                        priority: priority,
                        dueDate: dueDate
                    )
                    TaskManager.shared.add(task)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
