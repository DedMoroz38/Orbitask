import Cocoa
import SwiftUI

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
        return "Due \(Formatters.shortDate.string(from: task.dueDate))"
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
                VisualEffectView()
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.25))

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
