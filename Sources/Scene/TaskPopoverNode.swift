import SpriteKit

// MARK: - Shared helpers

/// Loads calendar.png from the app bundle and returns an SKSpriteNode sized to `size` points.
private func makeCalendarIconNode(size: CGFloat) -> SKSpriteNode? {
    guard let url = Bundle.main.url(forResource: "calendar", withExtension: "png"),
          let image = NSImage(contentsOf: url) else { return nil }
    let texture = SKTexture(image: image)
    return SKSpriteNode(texture: texture, size: CGSize(width: size, height: size))
}

/// A SpriteKit-based popover that shows task details when hovering over a meteor.
class TaskPopoverNode: SKNode {
    private static let popoverWidth: CGFloat = 260
    private static let cornerRadius: CGFloat = 18
    private static let padding: CGFloat = 16

    /// Returns the height this popover will occupy for a given task.
    static func preferredHeight(for task: CosmicTask) -> CGFloat {
        let hasDesc = !task.description.isEmpty
        let descHeight: CGFloat = hasDesc ? 16 : 0
        let descSpacing: CGFloat = hasDesc ? 6 : 0
        let sepSpacing: CGFloat = 10
        return padding
            + 20                               // titleHeight
            + descSpacing + descHeight
            + sepSpacing + 0.5 + sepSpacing    // separator
            + 16                               // infoRowHeight
            + sepSpacing + 14                  // hintHeight
            + padding
    }

    init(task: CosmicTask, backgroundTexture: SKTexture? = nil) {
        super.init()

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let dueString = formatter.string(from: task.dueDate)

        // Layout measurements
        let titleHeight: CGFloat = 20
        let hasDesc = !task.description.isEmpty
        let descHeight: CGFloat = hasDesc ? 16 : 0
        let descSpacing: CGFloat = hasDesc ? 6 : 0
        let sepSpacing: CGFloat = 10
        let infoRowHeight: CGFloat = 16
        let hintHeight: CGFloat = 14

        let totalHeight = Self.padding
            + titleHeight
            + descSpacing + descHeight
            + sepSpacing + 0.5 + sepSpacing
            + infoRowHeight
            + sepSpacing + hintHeight
            + Self.padding

        let bgRect = CGRect(
            x: -Self.popoverWidth / 2,
            y: 0,
            width: Self.popoverWidth,
            height: totalHeight
        )

        // Background: blurred scene capture (frosted glass) or opaque dark fallback
        if let bgTex = backgroundTexture {
            let blurEffect = SKEffectNode()
            blurEffect.shouldRasterize = true
            blurEffect.shouldEnableEffects = true
            blurEffect.filter = CIFilter(name: "CIGaussianBlur",
                                         parameters: ["inputRadius": 20])
            blurEffect.zPosition = 0
            let bgSprite = SKSpriteNode(texture: bgTex,
                                        size: CGSize(width: Self.popoverWidth, height: totalHeight))
            bgSprite.position = CGPoint(x: 0, y: totalHeight / 2)
            blurEffect.addChild(bgSprite)
            addChild(blurEffect)

            // Dark tint overlay so text stays readable
            let tint = SKShapeNode(rect: bgRect, cornerRadius: Self.cornerRadius)
            tint.fillColor = NSColor(white: 0.0, alpha: 0.50)
            tint.strokeColor = .clear
            tint.zPosition = 1
            addChild(tint)
        } else {
            let glassBg = SKShapeNode(rect: bgRect, cornerRadius: Self.cornerRadius)
            glassBg.fillColor = NSColor(white: 0.12, alpha: 0.85)
            glassBg.strokeColor = .clear
            glassBg.zPosition = 0
            addChild(glassBg)
        }

        // Border overlay
        let border = SKShapeNode(rect: bgRect, cornerRadius: Self.cornerRadius)
        border.fillColor = .clear
        border.strokeColor = NSColor(white: 1.0, alpha: 0.18)
        border.lineWidth = 0.5
        border.zPosition = 2
        addChild(border)

        // Inner light sheen
        let sheen = SKShapeNode(rect: bgRect.insetBy(dx: 1, dy: 1), cornerRadius: Self.cornerRadius - 1)
        sheen.fillColor = NSColor(white: 1.0, alpha: 0.04)
        sheen.strokeColor = .clear
        sheen.zPosition = 2
        addChild(sheen)

        let leftX = -Self.popoverWidth / 2 + Self.padding
        let maxTextWidth = Self.popoverWidth - Self.padding * 2
        var y = totalHeight - Self.padding

        // Title
        let titleLabel = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        titleLabel.text = task.title
        titleLabel.fontSize = 14
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .top
        titleLabel.position = CGPoint(x: leftX, y: y)
        titleLabel.zPosition = 5
        if titleLabel.frame.width > maxTextWidth {
            titleLabel.preferredMaxLayoutWidth = maxTextWidth
            titleLabel.numberOfLines = 1
        }
        addChild(titleLabel)
        y -= titleHeight

        // Description
        if hasDesc {
            y -= descSpacing
            let descLabel = SKLabelNode(fontNamed: "Helvetica Neue")
            descLabel.text = task.description
            descLabel.fontSize = 11
            descLabel.fontColor = NSColor(white: 1.0, alpha: 0.55)
            descLabel.horizontalAlignmentMode = .left
            descLabel.verticalAlignmentMode = .top
            descLabel.position = CGPoint(x: leftX, y: y)
            descLabel.zPosition = 5
            if descLabel.frame.width > maxTextWidth {
                descLabel.preferredMaxLayoutWidth = maxTextWidth
                descLabel.numberOfLines = 1
            }
            addChild(descLabel)
            y -= descHeight
        }

        // Separator
        y -= sepSpacing
        let sep = SKShapeNode(rect: CGRect(x: leftX, y: y, width: Self.popoverWidth - Self.padding * 2, height: 0.5))
        sep.fillColor = NSColor(white: 1.0, alpha: 0.1)
        sep.strokeColor = .clear
        sep.zPosition = 5
        addChild(sep)
        y -= 0.5 + sepSpacing

        // Info row: date left, priority right
        let calIconSize: CGFloat = 16
        let calIconSpacing: CGFloat = 4
        // Icon top-aligned with the row; labels use .baseline offset so caps
        // optically align with the icon center (baseline ≈ iconCenter - capHeight/2).
        let calIconCenterY = y - calIconSize / 2
        let labelBaselineY = calIconCenterY - 5 // 4pt ≈ half cap-height for 11pt font
        if let calIcon = makeCalendarIconNode(size: calIconSize) {
            calIcon.position = CGPoint(x: leftX + calIconSize / 2, y: calIconCenterY)
            calIcon.zPosition = 5
            addChild(calIcon)
        }
        let dateLabel = SKLabelNode(fontNamed: "Helvetica Neue")
        dateLabel.text = dueString
        dateLabel.fontSize = 11
        dateLabel.fontColor = NSColor(white: 1.0, alpha: 1.0)
        dateLabel.horizontalAlignmentMode = .left
        dateLabel.verticalAlignmentMode = .baseline
        dateLabel.position = CGPoint(x: leftX + calIconSize + calIconSpacing, y: labelBaselineY)
        dateLabel.zPosition = 5
        addChild(dateLabel)

        let priorityLabel = SKLabelNode(fontNamed: "Helvetica Neue Medium")
        priorityLabel.text = "●  \(task.priority.label)"
        priorityLabel.fontSize = 11
        priorityLabel.fontColor = Cosmic.priorityColor(task.priority)
        priorityLabel.horizontalAlignmentMode = .right
        priorityLabel.verticalAlignmentMode = .baseline
        priorityLabel.position = CGPoint(x: Self.popoverWidth / 2 - Self.padding, y: labelBaselineY - 5)
        priorityLabel.zPosition = 5
        addChild(priorityLabel)
        y -= infoRowHeight

        // Hint
        y -= sepSpacing
        let hint = SKLabelNode(fontNamed: "Helvetica Neue")
        hint.text = "Click for actions"
        hint.fontSize = 9
        hint.fontColor = NSColor.white.withAlphaComponent(0.3)
        hint.horizontalAlignmentMode = .center
        hint.verticalAlignmentMode = .top
        hint.position = CGPoint(x: 0, y: y)
        hint.zPosition = 5
        addChild(hint)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Edit Popover (click-to-edit)

/// A popover that appears when clicking a meteor, with action buttons.
/// Card-style design with frosted glass background.
class TaskEditPopoverNode: SKNode {
    enum Action { case complete, delete }

    private static let popoverWidth: CGFloat = 260
    private static let cornerRadius: CGFloat = 18
    private static let padding: CGFloat = 16
    private static let buttonHeight: CGFloat = 30
    private static let buttonSpacing: CGFloat = 8

    /// Returns the height this popover will occupy for a given task.
    static func preferredHeight(for task: CosmicTask) -> CGFloat {
        let hasDesc = !task.description.isEmpty
        let descHeight: CGFloat = hasDesc ? 16 : 0
        let descSpacing: CGFloat = hasDesc ? 6 : 0
        let sepSpacing: CGFloat = 10
        let buttonsArea: CGFloat = buttonHeight
        return padding
            + 20                               // titleHeight
            + descSpacing + descHeight
            + sepSpacing
            + 18                               // infoRowHeight
            + sepSpacing + 0.5 + sepSpacing    // separator
            + buttonsArea
            + padding
    }

    let task: CosmicTask

    /// Rectangles for hit testing (in local coordinates)
    private var completeButtonRect: CGRect = .zero
    private var deleteButtonRect: CGRect = .zero
    private var totalHeight: CGFloat = 0

    init(task: CosmicTask, backgroundTexture: SKTexture? = nil) {
        self.task = task
        super.init()

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let dueString = formatter.string(from: task.dueDate)

        // Layout measurements
        let titleHeight: CGFloat = 20
        let hasDesc = !task.description.isEmpty
        let descHeight: CGFloat = hasDesc ? 16 : 0
        let descSpacing: CGFloat = hasDesc ? 6 : 0
        let sepSpacing: CGFloat = 10
        let infoRowHeight: CGFloat = 18
        let buttonsArea: CGFloat = Self.buttonHeight

        totalHeight = Self.padding
            + titleHeight
            + descSpacing + descHeight
            + sepSpacing
            + infoRowHeight
            + sepSpacing + 0.5 + sepSpacing    // separator
            + buttonsArea
            + Self.padding

        let bgRect = CGRect(
            x: -Self.popoverWidth / 2,
            y: 0,
            width: Self.popoverWidth,
            height: totalHeight
        )

        // ── Background: blurred scene capture (frosted glass) or opaque dark fallback ──
        if let bgTex = backgroundTexture {
            let blurEffect = SKEffectNode()
            blurEffect.shouldRasterize = true
            blurEffect.shouldEnableEffects = true
            blurEffect.filter = CIFilter(name: "CIGaussianBlur",
                                         parameters: ["inputRadius": 20])
            blurEffect.zPosition = 0
            let bgSprite = SKSpriteNode(texture: bgTex,
                                        size: CGSize(width: Self.popoverWidth, height: totalHeight))
            bgSprite.position = CGPoint(x: 0, y: totalHeight / 2)
            blurEffect.addChild(bgSprite)
            addChild(blurEffect)

            // Dark tint overlay so text and buttons stay readable
            let tint = SKShapeNode(rect: bgRect, cornerRadius: Self.cornerRadius)
            tint.fillColor = NSColor(white: 0.0, alpha: 0.50)
            tint.strokeColor = .clear
            tint.zPosition = 1
            addChild(tint)
        } else {
            let glassBg = SKShapeNode(rect: bgRect, cornerRadius: Self.cornerRadius)
            glassBg.fillColor = NSColor(white: 0.12, alpha: 0.85)
            glassBg.strokeColor = .clear
            glassBg.zPosition = 0
            addChild(glassBg)
        }

        // Subtle outer border
        let border = SKShapeNode(rect: bgRect, cornerRadius: Self.cornerRadius)
        border.fillColor = .clear
        border.strokeColor = NSColor(white: 1.0, alpha: 0.18)
        border.lineWidth = 0.5
        border.zPosition = 2
        addChild(border)

        // Inner light sheen for glass depth
        let sheen = SKShapeNode(rect: bgRect.insetBy(dx: 1, dy: 1), cornerRadius: Self.cornerRadius - 1)
        sheen.fillColor = NSColor(white: 1.0, alpha: 0.04)
        sheen.strokeColor = .clear
        sheen.zPosition = 2
        addChild(sheen)

        // ── Content ──
        let leftX = -Self.popoverWidth / 2 + Self.padding
        let rightX = Self.popoverWidth / 2 - Self.padding
        let maxTextWidth = Self.popoverWidth - Self.padding * 2
        var y = totalHeight - Self.padding

        // Title
        let titleLabel = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        titleLabel.text = task.title
        titleLabel.fontSize = 14
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .top
        titleLabel.position = CGPoint(x: leftX, y: y)
        titleLabel.zPosition = 5
        if titleLabel.frame.width > maxTextWidth {
            titleLabel.preferredMaxLayoutWidth = maxTextWidth
            titleLabel.numberOfLines = 1
        }
        addChild(titleLabel)
        y -= titleHeight

        // Description
        if hasDesc {
            y -= descSpacing
            let descLabel = SKLabelNode(fontNamed: "Helvetica Neue")
            descLabel.text = task.description
            descLabel.fontSize = 11
            descLabel.fontColor = NSColor(white: 1.0, alpha: 0.55)
            descLabel.horizontalAlignmentMode = .left
            descLabel.verticalAlignmentMode = .top
            descLabel.position = CGPoint(x: leftX, y: y)
            descLabel.zPosition = 5
            if descLabel.frame.width > maxTextWidth {
                descLabel.preferredMaxLayoutWidth = maxTextWidth
                descLabel.numberOfLines = 1
            }
            addChild(descLabel)
            y -= descHeight
        }

        // ── Info row: date + priority ──
        y -= sepSpacing
        let calIconSize: CGFloat = 16
        let calIconSpacing: CGFloat = 4
        let calIconCenterY = y - calIconSize / 2
        let labelBaselineY = calIconCenterY - 4
        if let calIcon = makeCalendarIconNode(size: calIconSize) {
            calIcon.position = CGPoint(x: leftX + calIconSize / 2, y: calIconCenterY)
            calIcon.zPosition = 5
            addChild(calIcon)
        }
        let dateLabel = SKLabelNode(fontNamed: "Helvetica Neue")
        dateLabel.text = dueString
        dateLabel.fontSize = 11
        dateLabel.fontColor = NSColor(white: 1.0, alpha: 1.0)
        dateLabel.horizontalAlignmentMode = .left
        dateLabel.verticalAlignmentMode = .baseline
        dateLabel.position = CGPoint(x: leftX + calIconSize + calIconSpacing, y: labelBaselineY)
        dateLabel.zPosition = 5
        addChild(dateLabel)

        let priorityLabel = SKLabelNode(fontNamed: "Helvetica Neue Medium")
        priorityLabel.text = "●  \(task.priority.label)"
        priorityLabel.fontSize = 11
        priorityLabel.fontColor = Cosmic.priorityColor(task.priority)
        priorityLabel.horizontalAlignmentMode = .right
        priorityLabel.verticalAlignmentMode = .baseline
        priorityLabel.position = CGPoint(x: rightX, y: labelBaselineY)
        priorityLabel.zPosition = 5
        addChild(priorityLabel)
        y -= infoRowHeight

        // ── Separator 2 ──
        y -= sepSpacing
        addSeparator(at: y, leftX: leftX, width: maxTextWidth)
        y -= 0.5 + sepSpacing

        // ── Action buttons ──
        let totalButtonWidth = Self.popoverWidth - Self.padding * 2
        let halfButtonWidth = (totalButtonWidth - Self.buttonSpacing) / 2
        let white = NSColor.white

        completeButtonRect = makeButton(
            title: "✓  Complete", x: leftX, y: y - Self.buttonHeight,
            width: halfButtonWidth, height: Self.buttonHeight,
            color: white
        )

        deleteButtonRect = makeButton(
            title: "✕  Delete", x: leftX + halfButtonWidth + Self.buttonSpacing, y: y - Self.buttonHeight,
            width: halfButtonWidth, height: Self.buttonHeight,
            color: white
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Helpers

    private func addSeparator(at y: CGFloat, leftX: CGFloat, width: CGFloat) {
        let sep = SKShapeNode(rect: CGRect(x: leftX, y: y, width: width, height: 0.5))
        sep.fillColor = NSColor(white: 1.0, alpha: 0.1)
        sep.strokeColor = .clear
        sep.zPosition = 5
        addChild(sep)
    }

    @discardableResult
    private func makeButton(title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: NSColor) -> CGRect {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let bg = SKShapeNode(rect: rect, cornerRadius: 10)
        bg.fillColor = color.withAlphaComponent(0.15)
        bg.strokeColor = color.withAlphaComponent(0.35)
        bg.lineWidth = 0.5
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
        if deleteButtonRect.contains(local) { return .delete }
        return nil
    }

    /// Whether the scene-coordinate point is inside the whole popover background.
    func containsScenePoint(_ scenePoint: CGPoint) -> Bool {
        let local = convert(scenePoint, from: scene!)
        let localBounds = CGRect(
            x: -Self.popoverWidth / 2 - 8,
            y: -8,
            width: Self.popoverWidth + 16,
            height: totalHeight + 16
        )
        return localBounds.contains(local)
    }
}
