import SpriteKit

/// Represents a single task as a meteor in orbit around the planet.
class MeteorNode: SKNode {
    let task: CosmicTask

    /// Current angle on the orbit (radians)
    var orbitAngle: CGFloat

    /// Current orbit radius based on urgency
    var orbitRadius: CGFloat

    private let meteorBody: SKShapeNode
    private let trailEmitter: SKEmitterNode?
    private let label: SKLabelNode

    /// Whether the popover is currently shown
    var isHovered: Bool = false
    /// Whether this meteor is selected (edit popover open)
    var isSelected: Bool = false

    init(task: CosmicTask) {
        self.task = task

        // Calculate orbit position from urgency
        let urgency = CGFloat(task.urgency())
        self.orbitRadius = Cosmic.outerOrbit - urgency * (Cosmic.outerOrbit - Cosmic.innerOrbit)
        self.orbitAngle = CGFloat.random(in: 0...(2 * .pi))

        // Size scales with priority
        let sizeMultiplier: CGFloat = {
            switch task.priority {
            case .low: return 0.7
            case .medium: return 1.0
            case .high: return 1.3
            case .critical: return 1.6
            }
        }()
        let meteorSize = Cosmic.meteorBaseSize * sizeMultiplier

        // Main meteor body
        meteorBody = SKShapeNode(circleOfRadius: meteorSize / 2)
        meteorBody.fillColor = Cosmic.priorityColor(task.priority)
        meteorBody.strokeColor = Cosmic.priorityColor(task.priority).withAlphaComponent(0.6)
        meteorBody.lineWidth = 1.5
        meteorBody.glowWidth = 3.0
        meteorBody.zPosition = 20

        // Meteor inner glow
        let innerGlow = SKShapeNode(circleOfRadius: meteorSize / 3)
        innerGlow.fillColor = .white
        innerGlow.strokeColor = .clear
        innerGlow.alpha = 0.5
        innerGlow.zPosition = 21

        // Title label (shown near meteor, truncated)
        label = SKLabelNode(fontNamed: "Helvetica Neue")
        let maxChars = 18
        let truncated = task.title.count > maxChars
            ? String(task.title.prefix(maxChars - 1)) + "…"
            : task.title
        label.text = truncated
        label.fontSize = 10
        label.fontColor = .white
        label.alpha = 0.7
        label.verticalAlignmentMode = .bottom
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: meteorSize / 2 + 6)
        label.zPosition = 25

        // Create trail emitter programmatically
        trailEmitter = MeteorNode.createTrailEmitter(color: Cosmic.priorityColor(task.priority), meteorSize: meteorSize)

        super.init()

        addChild(meteorBody)
        meteorBody.addChild(innerGlow)
        addChild(label)

        if let emitter = trailEmitter {
            emitter.zPosition = 15
            emitter.targetNode = self.scene ?? self
            addChild(emitter)
        }

        // Critical tasks pulsate
        if task.priority == .critical {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            meteorBody.run(SKAction.repeatForever(pulse))
        }

        self.name = "meteor_\(task.id.uuidString)"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates the meteor's position on its orbit.
    func updatePosition(center: CGPoint, dt: TimeInterval) {
        // Slowly drift along the orbit
        let speed = Cosmic.meteorDriftSpeed / max(orbitRadius, 1)
        orbitAngle += CGFloat(dt) * speed

        // Smoothly update orbit radius based on current urgency
        let targetRadius = Cosmic.outerOrbit - CGFloat(task.urgency()) * (Cosmic.outerOrbit - Cosmic.innerOrbit)
        orbitRadius += (targetRadius - orbitRadius) * 0.01

        let x = center.x + cos(orbitAngle) * orbitRadius
        let y = center.y + sin(orbitAngle) * orbitRadius
        self.position = CGPoint(x: x, y: y)

        // Point trail emitter away from direction of travel
        trailEmitter?.emissionAngle = orbitAngle + .pi
    }

    /// Highlight on hover
    func setHighlighted(_ highlighted: Bool) {
        isHovered = highlighted
        let targetAlpha: CGFloat = highlighted ? 1.0 : 0.7
        label.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.2))
        applyScale()
    }

    /// Select/deselect (edit popover)
    func setSelected(_ selected: Bool) {
        isSelected = selected
        applyScale()
    }

    private func applyScale() {
        let target: CGFloat
        if isSelected { target = 1.5 }
        else if isHovered { target = 1.3 }
        else { target = 1.0 }
        self.run(SKAction.scale(to: target, duration: 0.2))
    }

    /// Creates a particle trail emitter programmatically (no .sks file needed).
    private static func createTrailEmitter(color: NSColor, meteorSize: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 40
        emitter.numParticlesToEmit = 0  // Continuous
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.3

        emitter.particleSize = CGSize(width: meteorSize * 0.4, height: meteorSize * 0.4)
        emitter.particleScaleSpeed = -0.5

        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = 0.6
        emitter.particleAlphaSpeed = -0.8

        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 0.3
        emitter.particleSpeed = 15
        emitter.particleSpeedRange = 5

        // Use a small white circle texture
        let texSize = 8
        let image = NSImage(size: NSSize(width: texSize, height: texSize), flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: rect)
            return true
        }
        emitter.particleTexture = SKTexture(image: image)
        emitter.particleBlendMode = .add

        return emitter
    }

    /// The hit-test area for hover detection.
    override func contains(_ point: CGPoint) -> Bool {
        let localPoint = convert(point, from: scene!)
        let hitRadius = max(Cosmic.meteorMaxSize, 20.0)
        return localPoint.length() <= hitRadius
    }
}

// MARK: - CGPoint helpers

extension CGPoint {
    func length() -> CGFloat {
        return sqrt(x * x + y * y)
    }

    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}
