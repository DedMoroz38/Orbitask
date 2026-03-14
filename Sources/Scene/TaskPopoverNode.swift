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

// MARK: - Edit Popover (click-to-edit)

/// A popover that appears when clicking a meteor, with action buttons.
class TaskEditPopoverNode: SKNode {
    enum Action { case complete, cyclePriority, delete }

    private static let popoverWidth: CGFloat = 240
    private static let lineHeight: CGFloat = 16
    private static let padding: CGFloat = 12
    private static let buttonHeight: CGFloat = 26
    private static let buttonSpacing: CGFloat = 6

    let task: CosmicTask

    /// Rectangles for hit testing (in scene coordinates once positioned)
    private var completeButtonRect: CGRect = .zero
    private var priorityButtonRect: CGRect = .zero
    private var deleteButtonRect: CGRect = .zero

    init(task: CosmicTask) {
        self.task = task
        super.init()

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .abbreviated

        let dueString = formatter.string(from: task.dueDate)
        let relativeString = relFormatter.localizedString(for: task.dueDate, relativeTo: Date())

        var lines: [(String, NSColor, CGFloat)] = []
        lines.append((task.title, .white, 13))
        if !task.description.isEmpty {
            lines.append((task.description, NSColor.white.withAlphaComponent(0.7), 10))
        }
        lines.append(("Priority: \(task.priority.label)", Cosmic.priorityColor(task.priority), 10))
        lines.append(("Due: \(dueString) (\(relativeString))", urgencyColor(task), 10))

        let infoHeight = Self.padding + CGFloat(lines.count) * Self.lineHeight + 4
        let buttonsHeight = Self.padding + 3 * Self.buttonHeight + 2 * Self.buttonSpacing + Self.padding
        let totalHeight = infoHeight + buttonsHeight

        // Background card
        let bg = SKShapeNode(rect: CGRect(
            x: -Self.popoverWidth / 2,
            y: 0,
            width: Self.popoverWidth,
            height: totalHeight
        ), cornerRadius: 8)
        bg.fillColor = NSColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 0.95)
        bg.strokeColor = Cosmic.priorityColor(task.priority).withAlphaComponent(0.5)
        bg.lineWidth = 1.0
        bg.zPosition = 0
        addChild(bg)

        // Accent bar
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

        // Info lines
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
            let maxWidth = Self.popoverWidth - Self.padding * 2
            if label.frame.width > maxWidth {
                label.preferredMaxLayoutWidth = maxWidth
                label.numberOfLines = 1
            }
            addChild(label)
            y -= Self.lineHeight
        }

        // Buttons area
        y -= Self.padding

        let buttonWidth = Self.popoverWidth - Self.padding * 2
        let buttonX = -Self.popoverWidth / 2 + Self.padding

        completeButtonRect = makeButton(
            title: "✓  Complete", x: buttonX, y: y - Self.buttonHeight,
            width: buttonWidth, height: Self.buttonHeight,
            color: NSColor(red: 0.18, green: 0.72, blue: 0.35, alpha: 1.0)
        )
        y -= Self.buttonHeight + Self.buttonSpacing

        priorityButtonRect = makeButton(
            title: "↻  Cycle Priority", x: buttonX, y: y - Self.buttonHeight,
            width: buttonWidth, height: Self.buttonHeight,
            color: NSColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1.0)
        )
        y -= Self.buttonHeight + Self.buttonSpacing

        deleteButtonRect = makeButton(
            title: "✕  Delete", x: buttonX, y: y - Self.buttonHeight,
            width: buttonWidth, height: Self.buttonHeight,
            color: NSColor(red: 0.85, green: 0.22, blue: 0.22, alpha: 1.0)
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    private func makeButton(title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: NSColor) -> CGRect {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let bg = SKShapeNode(rect: rect, cornerRadius: 6)
        bg.fillColor = color.withAlphaComponent(0.25)
        bg.strokeColor = color.withAlphaComponent(0.6)
        bg.lineWidth = 1.0
        bg.zPosition = 3
        addChild(bg)

        let label = SKLabelNode(fontNamed: "Helvetica Neue Medium")
        label.text = title
        label.fontSize = 11
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: x + width / 2, y: y + height / 2)
        label.zPosition = 4
        addChild(label)

        return rect
    }

    /// Hit-tests a point in **scene** coordinates and returns the tapped action, if any.
    func hitTest(scenePoint: CGPoint) -> Action? {
        let local = convert(scenePoint, from: scene!)
        if completeButtonRect.contains(local) { return .complete }
        if priorityButtonRect.contains(local) { return .cyclePriority }
        if deleteButtonRect.contains(local) { return .delete }
        return nil
    }

    /// Whether the scene-coordinate point is inside the whole popover background.
    func containsScenePoint(_ scenePoint: CGPoint) -> Bool {
        let local = convert(scenePoint, from: scene!)
        // Use a generous rect around the popover
        let bounds = calculateAccumulatedFrame()
        let localBounds = CGRect(
            x: -Self.popoverWidth / 2 - 8,
            y: -8,
            width: Self.popoverWidth + 16,
            height: bounds.height + 16
        )
        return localBounds.contains(local)
    }

    private func urgencyColor(_ task: CosmicTask) -> NSColor {
        let u = task.urgency()
        if u > 0.8 { return NSColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0) }
        if u > 0.5 { return NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) }
        return NSColor.white.withAlphaComponent(0.7)
    }
}
