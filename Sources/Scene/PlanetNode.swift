import SpriteKit

/// The central planet node with a glowing atmosphere effect.
class PlanetNode: SKNode {
    private let sprite: SKSpriteNode
    private let glow: SKShapeNode
    private let atmosphere: SKShapeNode

    override init() {
        // Planet sprite from planet.png
        let texture = SKTexture(imageNamed: "planet")
        let diameter = Cosmic.planetRadius * 3
        sprite = SKSpriteNode(texture: texture,
                              size: CGSize(width: diameter, height: diameter))
        sprite.zPosition = 10

        // Inner atmosphere ring
        atmosphere = SKShapeNode(circleOfRadius: Cosmic.planetRadius + 8)
        atmosphere.fillColor = .clear
        atmosphere.strokeColor = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.4)
        atmosphere.lineWidth = 4.0
        atmosphere.glowWidth = 6.0
        atmosphere.zPosition = 9

        // Outer glow
        glow = SKShapeNode(circleOfRadius: Cosmic.planetGlowRadius)
        glow.fillColor = Cosmic.planetGlowColor
        glow.strokeColor = .clear
        glow.zPosition = 8

        super.init()

        addChild(glow)
        addChild(atmosphere)
        addChild(sprite)

        // Gentle pulsing glow animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 3.0),
            SKAction.scale(to: 0.95, duration: 3.0)
        ])
        glow.run(SKAction.repeatForever(pulse))

        // Slow rotation of atmosphere
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 60)
        atmosphere.run(SKAction.repeatForever(rotate))

        // Slow self-rotation of the planet sprite
        let spinPlanet = SKAction.rotate(byAngle: .pi * 2, duration: 120)
        sprite.run(SKAction.repeatForever(spinPlanet))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
