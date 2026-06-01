import Cocoa
import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var taskManager = TaskManager.shared
    @State private var showingAddTask = false
    var onClose: (() -> Void)?

    var body: some View {
        ZStack {
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
            .clipShape(RoundedRectangle(cornerRadius: 30))
        )
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
