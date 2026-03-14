import SpriteKit

/// A SpriteKit-based popover that shows task details when hovering over a meteor.
class TaskPopoverNode: SKNode {
    private static let popoverWidth: CGFloat = 240
    private static let lineHeight: CGFloat = 16
    private static let padding: CGFloat = 12

    init(task: CosmicTask) {
        super.init()

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .abbreviated

        let dueString = formatter.string(from: task.dueDate)
        let relativeString = relFormatter.localizedString(for: task.dueDate, relativeTo: Date())

        // Build text lines
        var lines: [(String, NSColor, CGFloat)] = []
        lines.append((task.title, .white, 13))
        if !task.description.isEmpty {
            lines.append((task.description, NSColor.white.withAlphaComponent(0.7), 10))
        }
        lines.append(("Priority: \(task.priority.label)", Cosmic.priorityColor(task.priority), 10))
        lines.append(("Due: \(dueString) (\(relativeString))", urgencyColor(task), 10))

        // Calculate height
        let totalHeight = Self.padding * 2 + CGFloat(lines.count) * Self.lineHeight + 4

        // Background card
        let bg = SKShapeNode(rect: CGRect(
            x: -Self.popoverWidth / 2,
            y: 0,
            width: Self.popoverWidth,
            height: totalHeight
        ), cornerRadius: 8)
        bg.fillColor = NSColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 0.92)
        bg.strokeColor = Cosmic.priorityColor(task.priority).withAlphaComponent(0.5)
        bg.lineWidth = 1.0
        bg.zPosition = 0
        addChild(bg)

        // Priority accent bar
        let accent = SKShapeNode(rect: CGRect(
            x: -Self.popoverWidth / 2,
            y: totalHeight - 3,
            width: Self.popoverWidth,
            height: 3
        ), cornerRadius: 1.5)
        accent.fillColor = Cosmic.priorityColor(task.priority)
        accent.strokeColor = .clear
        accent.zPosition = 1
        addChild(accent)

        // Render text lines
        var y = totalHeight - Self.padding - Self.lineHeight
        for (text, color, fontSize) in lines {
            let label = SKLabelNode(fontNamed: "Helvetica Neue")
            label.text = text
            label.fontSize = fontSize
            label.fontColor = color
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.position = CGPoint(x: -Self.popoverWidth / 2 + Self.padding, y: y)
            label.zPosition = 2

            // Truncate if too long
            let maxWidth = Self.popoverWidth - Self.padding * 2
            if label.frame.width > maxWidth {
                label.preferredMaxLayoutWidth = maxWidth
                label.numberOfLines = 1
            }

            addChild(label)
            y -= Self.lineHeight
        }

        // Small hint
        let hint = SKLabelNode(fontNamed: "Helvetica Neue")
        hint.text = "Double-click to complete"
        hint.fontSize = 8
        hint.fontColor = NSColor.white.withAlphaComponent(0.35)
        hint.horizontalAlignmentMode = .center
        hint.verticalAlignmentMode = .top
        hint.position = CGPoint(x: 0, y: -4)
        hint.zPosition = 2
        addChild(hint)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func urgencyColor(_ task: CosmicTask) -> NSColor {
        let u = task.urgency()
        if u > 0.8 { return NSColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0) }
        if u > 0.5 { return NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) }
        return NSColor.white.withAlphaComponent(0.7)
    }
}
