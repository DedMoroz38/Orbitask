import SpriteKit

/// The central planet node with a glowing atmosphere effect.
class PlanetNode: SKNode {
    private let body: SKShapeNode
    private let glow: SKShapeNode
    private let atmosphere: SKShapeNode

    override init() {
        // Main planet body with gradient-like layering
        body = SKShapeNode(circleOfRadius: Cosmic.planetRadius)
        body.fillColor = Cosmic.planetColor
        body.strokeColor = NSColor(red: 0.15, green: 0.4, blue: 0.8, alpha: 1.0)
        body.lineWidth = 2.0
        body.zPosition = 10

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
        addChild(body)

        // Add surface detail dots to the planet
        addSurfaceDetails()

        // Gentle pulsing glow animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 3.0),
            SKAction.scale(to: 0.95, duration: 3.0)
        ])
        glow.run(SKAction.repeatForever(pulse))

        // Slow rotation of atmosphere
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 60)
        atmosphere.run(SKAction.repeatForever(rotate))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addSurfaceDetails() {
        // Add crater-like spots on the planet surface
        let spotCount = 6
        for i in 0..<spotCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(spotCount)) + CGFloat.random(in: -0.3...0.3)
            let dist = CGFloat.random(in: 10...Cosmic.planetRadius * 0.7)
            let radius = CGFloat.random(in: 4...12)

            let spot = SKShapeNode(circleOfRadius: radius)
            spot.fillColor = NSColor(red: 0.15, green: 0.35, blue: 0.7, alpha: 0.4)
            spot.strokeColor = .clear
            spot.position = CGPoint(x: cos(angle) * dist, y: sin(angle) * dist)
            spot.zPosition = 11
            body.addChild(spot)
        }
    }
}
