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

        let menuView = MenuBarView(onClose: { [weak self] in
            self?.popover.performClose(nil)
        })
        let hc = NSHostingController(rootView: menuView)
        hc.view.wantsLayer = true
        popover.contentViewController = hc
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Clear the popover window's own background so our SwiftUI clipShape shows through
            if let win = popover.contentViewController?.view.window {
                win.backgroundColor = .clear
                win.isOpaque = false
            }
            if let wrapper = popover.contentViewController?.view.superview {
                wrapper.wantsLayer = true
                wrapper.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
}

// MARK: - Visual Effect Background

private struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - SwiftUI Menu Bar View

struct MenuBarView: View {
    @ObservedObject private var taskManager = TaskManager.shared
    @State private var showingAddTask = false
    var onClose: (() -> Void)?

    var body: some View {
        ZStack {
            // Main panel
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(NSColor(red: 0.4, green: 0.65, blue: 1.0, alpha: 1.0)))

                    Text("Cosmic Tasks")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Close button — white × in thin-bordered circle
                    Button(action: { onClose?() }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.30), lineWidth: 0.5)
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.5)

                if taskManager.activeTasks.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "moon.stars")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.25))
                        Text("No active tasks")
                            .foregroundColor(.white.opacity(0.45))
                        Text("All clear — the cosmos is at peace")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.25))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(taskManager.activeTasks) { task in
                                TaskRowView(task: task)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                }

                // Separator + floating + button overlaid on its bottom-right
                ZStack(alignment: .bottomTrailing) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)

                    Button(action: { withAnimation(.spring(response: 0.3)) { showingAddTask = true } }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.30), lineWidth: 0.5)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .offset(x: -14, y: -14)
                }

                // Footer
                HStack {
                    Text("\(taskManager.activeTasks.count) active")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.35))
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            // Inline add-task overlay
            if showingAddTask {
                AddTaskSheet(isPresented: $showingAddTask)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: 340, height: 480)
        .background(
            ZStack {
                VisualEffectView()
                Color.black.opacity(0.55)
            }
            .clipShape(RoundedRectangle(cornerRadius: 40))
        )
        .clipShape(RoundedRectangle(cornerRadius: 40))
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: CosmicTask

    private var priorityColor: Color {
        switch task.priority {
        case .low:      return Color(NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0))
        case .medium:   return Color(NSColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1.0))
        case .high:     return Color(NSColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0))
        case .critical: return Color(NSColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0))
        }
    }

    private var subtitleText: String {
        if !task.description.isEmpty { return task.description }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "Due \(formatter.string(from: task.dueDate))"
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            // Complete — white tick on circular background
            Button(action: { TaskManager.shared.complete(task.id) }) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12))
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            // Delete — white xmark on circular background
            Button(action: { TaskManager.shared.remove(task.id) }) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12))
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Frosted glass blur — same material as the planet pop-ups
                VisualEffectView()
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                // Slight dark tint so text stays readable
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.25))

                // Priority-colored gradient border
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            colors: [
                                priorityColor.opacity(0.85),
                                priorityColor.opacity(0.25),
                                priorityColor.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )

                // Inner top sheen
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 0.5
                    )
            }
        )
    }
}

// MARK: - Add Task Sheet

struct AddTaskSheet: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var link = ""
    @State private var priority: TaskPriority = .medium
    @State private var dueDate = Date().addingTimeInterval(24 * 3600)

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .low:      return Color(NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0))
        case .medium:   return Color(NSColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1.0))
        case .high:     return Color(NSColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0))
        case .critical: return Color(NSColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0))
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                // ── Title ──
                Text("New Task")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                // ── Task title field ──
                CosmicTextField(placeholder: "Task title", text: $title)

                // ── Description field ──
                CosmicTextField(placeholder: "Description (optional)", text: $description)

                // ── Link field ──
                CosmicTextField(placeholder: "Link (optional)", text: $link, icon: "link")

                // ── Priority picker ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("Priority")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))

                    LiquidGlassPriorityPicker(selection: $priority, colorFor: priorityColor)
                }

                // ── Due date picker ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("Due date")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))

                    CosmicDatePicker(date: $dueDate)
                }

                // ── Actions ──
                HStack(spacing: 8) {
                    Button(action: { withAnimation(.spring(response: 0.3)) { isPresented = false } }) {
                        Text("Cancel")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)

                    Button(action: {
                        let task = CosmicTask(title: title, description: description,
                                             priority: priority, dueDate: dueDate, link: link)
                        TaskManager.shared.add(task)
                        withAnimation(.spring(response: 0.3)) { isPresented = false }
                    }) {
                        Text("Add Task")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(title.isEmpty ? .white.opacity(0.25) : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(title.isEmpty
                                          ? Color.white.opacity(0.05)
                                          : Color.white.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(title.isEmpty
                                            ? Color.white.opacity(0.08)
                                            : Color.white.opacity(0.35),
                                            lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(title.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                // Blurry frosted glass fill
                VisualEffectView()
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                // Dark tint over the blur
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black.opacity(0.45))
                // Border
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        )
        .padding(20)
    }
}

// MARK: - Priority Frame Preference Key

private struct PriorityFrameKey: PreferenceKey {
    static var defaultValue: [TaskPriority: CGRect] = [:]
    static func reduce(value: inout [TaskPriority: CGRect], nextValue: () -> [TaskPriority: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Liquid Glass Priority Picker

private struct LiquidGlassPriorityPicker: View {
    @Binding var selection: TaskPriority
    let colorFor: (TaskPriority) -> Color

    @State private var frames: [TaskPriority: CGRect] = [:]
    @State private var capLeading: CGFloat = 0
    @State private var capTrailing: CGFloat = 0
    @State private var ready = false

    private var capWidth: CGFloat { max(1, capTrailing - capLeading) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TaskPriority.allCases, id: \.self) { p in
                let isSelected = selection == p
                Button(action: { select(p) }) {
                    Text(p.label)
                        .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.38))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: PriorityFrameKey.self,
                                    value: [p: geo.frame(in: .named("liqpicker"))]
                                )
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .coordinateSpace(name: "liqpicker")
        .onPreferenceChange(PriorityFrameKey.self) { newFrames in
            frames = newFrames
            if !ready, let f = frames[selection] {
                capLeading = f.minX
                capTrailing = f.maxX
                ready = true
            }
        }
        .background(alignment: .topLeading) {
            if ready {
                glassView
                    .frame(width: capWidth)
                    .frame(maxHeight: .infinity)
                    .offset(x: capLeading)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var glassView: some View {
        ZStack {
            // Glass body
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06), Color.white.opacity(0.12)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Top specular sheen
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .center
                    )
                )
                .mask(VStack(spacing: 0) { Rectangle().frame(height: 10); Spacer() })

            // Border glow
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.black.opacity(0.15), Color.black.opacity(0.35)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // Inner edge highlight
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.clear, Color.white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
                .padding(0.5)
        }
        .shadow(color: Color.white.opacity(0.25), radius: 10, x: 0, y: 2)
    }

    private func select(_ p: TaskPriority) {
        guard p != selection else { return }
        guard let oldFrame = frames[selection], let newFrame = frames[p] else {
            selection = p
            return
        }
        let goingRight = newFrame.midX > oldFrame.midX

        // Phase 1: Stretch the capsule toward the target (fast, no bounce)
        withAnimation(.spring(response: 0.18, dampingFraction: 0.92)) {
            if goingRight {
                capTrailing = newFrame.maxX
            } else {
                capLeading = newFrame.minX
            }
        }

        // Phase 2: Contract the trailing edge + update selection (bouncy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selection = p
            withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
                if goingRight {
                    capLeading = newFrame.minX
                } else {
                    capTrailing = newFrame.maxX
                }
            }
        }
    }
}

// MARK: - Custom text field

private struct CosmicTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.leading, 10)
            }
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.28))
                        .padding(.horizontal, icon != nil ? 0 : 10)
                }
                TextField("", text: $text)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, icon != nil ? 0 : 10)
                    .padding(.vertical, 13)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Custom calendar date picker

private struct CosmicDatePicker: View {
    @Binding var date: Date
    @State private var displayedMonth: Date = Date()
    private let cal = Calendar.current
    private let weekdays = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let startWeekday = cal.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: startWeekday)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(d)
            }
        }
        return days
    }

    private func isSelected(_ d: Date) -> Bool {
        cal.isDate(d, inSameDayAs: date)
    }

    private func isToday(_ d: Date) -> Bool {
        cal.isDateInToday(d)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Month navigation
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = daysInMonth()
            let rows = stride(from: 0, to: days.count, by: 7).map { Array(days.dropFirst($0).prefix(7)) }
            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { colIdx in
                        if colIdx < rows[rowIdx].count, let d = rows[rowIdx][colIdx] {
                            let dayNum = cal.component(.day, from: d)
                            let selected = isSelected(d)
                            let today = isToday(d)
                            Button(action: {
                                // Preserve time, change date
                                let timeComps = cal.dateComponents([.hour, .minute], from: date)
                                var dayComps = cal.dateComponents([.year, .month, .day], from: d)
                                dayComps.hour = timeComps.hour
                                dayComps.minute = timeComps.minute
                                if let newDate = cal.date(from: dayComps) {
                                    withAnimation(.easeInOut(duration: 0.15)) { date = newDate }
                                }
                            }) {
                                Text("\(dayNum)")
                                    .font(.system(size: 10, weight: selected ? .bold : .regular))
                                    .foregroundColor(selected ? .white : today ? .white.opacity(0.9) : .white.opacity(0.55))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 26)
                                    .background(
                                        Group {
                                            if selected {
                                                Circle()
                                                    .fill(Color.white.opacity(0.18))
                                                    .overlay(
                                                        Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                                                    )
                                            } else if today {
                                                Circle()
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                        }
                    }
                }
            }

            // Time row
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))

                Text(timeString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // Hour steppers
                HStack(spacing: 2) {
                    Button(action: { date = cal.date(byAdding: .hour, value: -1, to: date) ?? date }) {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Text("hr")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))

                    Button(action: { date = cal.date(byAdding: .hour, value: 1, to: date) ?? date }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                // Minute steppers
                HStack(spacing: 2) {
                    Button(action: { date = cal.date(byAdding: .minute, value: -5, to: date) ?? date }) {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Text("min")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))

                    Button(action: { date = cal.date(byAdding: .minute, value: 5, to: date) ?? date }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .onAppear { displayedMonth = date }
    }
}
