import SwiftUI

private struct PriorityFrameKey: PreferenceKey {
    static var defaultValue: [TaskPriority: CGRect] = [:]
    static func reduce(value: inout [TaskPriority: CGRect], nextValue: () -> [TaskPriority: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct LiquidGlassPriorityPicker: View {
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
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06), Color.white.opacity(0.12)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .center
                    )
                )
                .mask(VStack(spacing: 0) { Rectangle().frame(height: 10); Spacer() })

            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.black.opacity(0.15), Color.black.opacity(0.35)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

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

        withAnimation(.spring(response: 0.18, dampingFraction: 0.92)) {
            if goingRight { capTrailing = newFrame.maxX } else { capLeading = newFrame.minX }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selection = p
            withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
                if goingRight { capLeading = newFrame.minX } else { capTrailing = newFrame.maxX }
            }
        }
    }
}
