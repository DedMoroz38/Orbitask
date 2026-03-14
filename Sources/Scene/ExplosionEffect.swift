import SpriteKit

/// Explosion particle effect for when a task is completed.
class ExplosionEffect {
    /// Creates and runs an explosion at the given position in the scene.
    static func explode(at position: CGPoint, color: NSColor, in scene: SKScene) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 100

        emitter.particleBirthRate = 200
        emitter.numParticlesToEmit = 60
        emitter.particleLifetime = 1.0
        emitter.particleLifetimeRange = 0.5

        emitter.particleSize = CGSize(width: 6, height: 6)
        emitter.particleScaleSpeed = -0.8

        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.0

        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 60

        emitter.particleBlendMode = .add

        // Create texture
        let texSize = 8
        let image = NSImage(size: NSSize(width: texSize, height: texSize), flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: rect)
            return true
        }
        emitter.particleTexture = SKTexture(image: image)

        scene.addChild(emitter)

        // Flash ring
        let ring = SKShapeNode(circleOfRadius: 5)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = color
        ring.lineWidth = 3.0
        ring.glowWidth = 5.0
        ring.alpha = 1.0
        ring.zPosition = 99
        scene.addChild(ring)

        let expand = SKAction.group([
            SKAction.scale(to: 8.0, duration: 0.6),
            SKAction.fadeOut(withDuration: 0.6)
        ])
        ring.run(SKAction.sequence([expand, SKAction.removeFromParent()]))

        // Remove emitter after particles die
        let wait = SKAction.wait(forDuration: 2.0)
        emitter.run(SKAction.sequence([wait, SKAction.removeFromParent()]))
    }

    /// Subtle absorption effect — meteor spirals into the planet.
    static func absorb(node: SKNode, toward center: CGPoint, color: NSColor, in scene: SKScene, completion: @escaping () -> Void) {
        let spiral = SKAction.customAction(withDuration: 0.6) { node, elapsed in
            let progress = elapsed / 0.6
            let currentRadius = node.position.distance(to: center) * (1 - progress)
            let angle = CGFloat(elapsed) * 8.0  // Fast spiral
            node.position = CGPoint(
                x: center.x + cos(angle) * currentRadius,
                y: center.y + sin(angle) * currentRadius
            )
            node.setScale(max(0, 1.0 - progress))
            node.alpha = max(0, 1.0 - progress)
        }

        node.run(SKAction.sequence([spiral, SKAction.removeFromParent()])) {
            ExplosionEffect.explode(at: center, color: color, in: scene)
            completion()
        }
    }
}
