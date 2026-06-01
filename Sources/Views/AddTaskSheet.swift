import Cocoa
import SwiftUI

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

                Text("New Task")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                CosmicTextField(placeholder: "Task title", text: $title)
                CosmicTextField(placeholder: "Description (optional)", text: $description)
                CosmicTextField(placeholder: "Link (optional)", text: $link, icon: "link")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Priority")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))

                    LiquidGlassPriorityPicker(selection: $priority, colorFor: priorityColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Due date")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))

                    CosmicDatePicker(date: $dueDate)
                }

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
                VisualEffectView()
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.black.opacity(0.45))
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        )
        .padding(20)
    }
}
