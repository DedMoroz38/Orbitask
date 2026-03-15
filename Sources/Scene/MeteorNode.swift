import SpriteKit

/// Represents a single task as a meteor in orbit around the planet.
class MeteorNode: SKNode {
    let task: CosmicTask

    /// Current angle on the orbit (radians)
    var orbitAngle: CGFloat

    /// Current orbit radius based on urgency
    var orbitRadius: CGFloat

    /// The visible size of this meteor sprite (diameter).
    let meteorSize: CGFloat

    private let meteorSprite: SKSpriteNode
    private let pulseRing: SKShapeNode
    private let backFlame: SKEmitterNode
    private let frontFlame: SKEmitterNode
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
        self.meteorSize = Cosmic.meteorBaseSize * sizeMultiplier

        // Meteor sprite from meteor.png
        let texture = SKTexture(imageNamed: "meteor")
        meteorSprite = SKSpriteNode(texture: texture,
                                    size: CGSize(width: meteorSize, height: meteorSize))
        meteorSprite.color = Cosmic.priorityColor(task.priority)
        meteorSprite.colorBlendFactor = 0.25
        meteorSprite.zPosition = 20

        // Soft energy glow — filled disc behind the meteor, like the planet's glow layer
        // Radius slightly larger than the sprite so the edge peeks out from under it
        let ringRadius = meteorSize * 0.68
        pulseRing = SKShapeNode(circleOfRadius: ringRadius)
        pulseRing.fillColor = NSColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 0.4)
        pulseRing.strokeColor = .clear
        pulseRing.glowWidth = 8.0
        pulseRing.zPosition = 19

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

        // Flame trail emitters
        let priorityColor = Cosmic.priorityColor(task.priority)
        backFlame = MeteorNode.createFlameEmitter(color: priorityColor, meteorSize: meteorSize, isOverlay: false)
        frontFlame = MeteorNode.createFlameEmitter(color: priorityColor, meteorSize: meteorSize, isOverlay: true)

        super.init()

        backFlame.zPosition = 15
        frontFlame.zPosition = 22
        addChild(backFlame)
        addChild(pulseRing)
        addChild(meteorSprite)
        addChild(frontFlame)
        addChild(label)

        // Ripple pulse — expands outward from scale 1 to 1.6 while fading to 0,
        // then snaps back to scale 1 at full alpha and repeats.
        let ripple = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.0, duration: 1.4),
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.6, duration: 0.15),
                    SKAction.fadeAlpha(to: 0.0, duration: 1.25)
                ])
            ]),
            SKAction.run { [weak self] in
                self?.pulseRing.setScale(0.6)
                self?.pulseRing.alpha = 0.6
            },
            SKAction.wait(forDuration: Double.random(in: 0.4...1.0))
        ])
        pulseRing.alpha = 0.6
        pulseRing.run(SKAction.sequence([
            SKAction.wait(forDuration: Double.random(in: 0...2.5)),
            SKAction.repeatForever(ripple)
        ]))

        // Critical tasks: sprite gently pulses too
        if task.priority == .critical {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.45),
                SKAction.scale(to: 1.0,  duration: 0.45)
            ])
            meteorSprite.run(SKAction.repeatForever(pulse))
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

        // Flame points radially outward from planet
        backFlame.emissionAngle = orbitAngle
        frontFlame.emissionAngle = orbitAngle

        // Rotate oval particles so their long axis aligns with the travel direction
        backFlame.particleRotation = orbitAngle - .pi / 2
        frontFlame.particleRotation = orbitAngle - .pi / 2

        // Back flame originates from the planet-facing edge of the meteor
        let backOffset = meteorSize * 0.35
        backFlame.position = CGPoint(x: cos(orbitAngle) * backOffset, y: sin(orbitAngle) * backOffset)

        // Front overlay originates further back so its wide-angle spread crosses the meteor face
        let frontOffset = meteorSize * 0.48
        frontFlame.position = CGPoint(x: cos(orbitAngle) * frontOffset, y: sin(orbitAngle) * frontOffset)
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

    /// Creates a flame trail emitter.
    /// - isOverlay: if true, a slow wide-angle overlay that drifts across the meteor face.
    private static func createFlameEmitter(color: NSColor, meteorSize: CGFloat, isOverlay: Bool) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.numParticlesToEmit = 0  // Continuous

        if isOverlay {
            // Slow, wide-angle particles that originate behind the meteor and
            // drift across its face — makes the rock feel embedded in the flame.
            emitter.particleBirthRate = 22
            emitter.particleLifetime = 0.65
            emitter.particleLifetimeRange = 0.2
            emitter.particleSize = CGSize(width: meteorSize * 0.95, height: meteorSize * 1.1)
            emitter.particleAlpha = 0.22
            emitter.particleAlphaSpeed = -0.28
            emitter.particleSpeed = 22          // enough to cross the meteor diameter
            emitter.particleSpeedRange = 10
            emitter.emissionAngleRange = 1.3    // ~75° spread — fans across the sprite
        } else {
            // Dense trailing flame behind the meteor
            emitter.particleBirthRate = 55
            emitter.particleLifetime = 1.0
            emitter.particleLifetimeRange = 0.3
            emitter.particleSize = CGSize(width: meteorSize * 0.9, height: meteorSize * 1.0)
            emitter.particleAlpha = 0.75
            emitter.particleAlphaSpeed = -0.65
            emitter.particleSpeed = 20
            emitter.particleSpeedRange = 8
            emitter.emissionAngleRange = 0.55   // tighter core trail
        }

        emitter.particleScaleSpeed = -0.45
        emitter.emissionAngle = 0

        // yellow core → priority color → red-orange embers → transparent
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                NSColor(red: 1.0, green: 0.92, blue: 0.45, alpha: 1.0),
                color,
                NSColor(red: 0.9, green: 0.25, blue: 0.1, alpha: 0.6),
                NSColor(red: 0.3, green: 0.08, blue: 0.02, alpha: 0.0)
            ],
            times: [0, 0.25, 0.65, 1.0]
        )

        // Soft radial gradient texture for natural flame particles
        let texSize = 16
        let image = NSImage(size: NSSize(width: texSize, height: texSize), flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                NSColor.white.cgColor,
                NSColor.white.withAlphaComponent(0).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                ctx.drawRadialGradient(gradient,
                                       startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: CGFloat(texSize) / 2,
                                       options: .drawsAfterEndLocation)
            }
            return true
        }
        emitter.particleTexture = SKTexture(image: image)
        emitter.particleBlendMode = .add

        return emitter
    }

    /// Animates the meteor flying into the planet on completion.
    /// Only the meteor sprite rotates; flame direction tracks the planet independently.
    func animateCompletion(toward center: CGPoint, in scene: SKScene, completion: @escaping () -> Void) {
        let startPosition = self.position
        let duration: Double = 1.4

        // Stop ambient animations that would fight the completion sequence
        pulseRing.removeAllActions()
        label.removeAllActions()
        meteorSprite.removeAllActions()

        // Spin only the meteor sprite — flames are children of self, not meteorSprite, so they are unaffected
        meteorSprite.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: -.pi * 4, duration: 1.0)   // 2 full spins per second
        ))

        // Fade label out quickly
        label.run(SKAction.fadeOut(withDuration: 0.25))

        let travel = SKAction.customAction(withDuration: duration) { [weak self] node, elapsed in
            guard let self = self else { return }
            let t = CGFloat(elapsed) / CGFloat(duration)          // 0 → 1
            let eased = 1 - pow(1 - t, 3)                        // cubic ease-in (accelerates toward planet)

            // Move whole node toward planet center
            let newX = startPosition.x + (center.x - startPosition.x) * eased
            let newY = startPosition.y + (center.y - startPosition.y) * eased
            node.position = CGPoint(x: newX, y: newY)

            // Shrink and fade as it nears the planet
            node.setScale(max(0, 1.0 - t * 0.85))
            node.alpha = max(0, 1.0 - t * 1.3)

            // Recalculate flame direction based on live position → keep pointing away from planet
            let angle = atan2(newY - center.y, newX - center.x)
            self.backFlame.emissionAngle = angle
            self.frontFlame.emissionAngle = angle
            self.backFlame.particleRotation = angle - .pi / 2
            self.frontFlame.particleRotation = angle - .pi / 2
            let backOff = self.meteorSize * 0.35
            let frontOff = self.meteorSize * 0.48
            self.backFlame.position = CGPoint(x: cos(angle) * backOff, y: sin(angle) * backOff)
            self.frontFlame.position = CGPoint(x: cos(angle) * frontOff, y: sin(angle) * frontOff)
        }

        run(travel) { [weak self] in
            guard let self = self else { return }
            self.removeFromParent()
            ExplosionEffect.explode(at: center, color: Cosmic.priorityColor(self.task.priority), in: scene)
            completion()
        }
    }

    /// Hit-test area matches the visible meteor sprite bounds.
    override func contains(_ point: CGPoint) -> Bool {
        let localPoint = convert(point, from: scene!)
        return localPoint.length() <= meteorSize / 2
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
