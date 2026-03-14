import SpriteKit

/// A procedural starfield background with layered parallax stars.
class StarfieldNode: SKNode {
    func populate(in size: CGSize) {
        removeAllChildren()

        let layers: [(count: Int, sizeRange: ClosedRange<CGFloat>, alpha: CGFloat)] = [
            (120, 0.5...1.0, 0.3),   // Distant dim stars
            (60,  1.0...2.0, 0.5),   // Mid-range
            (25,  1.5...3.0, 0.8),   // Bright foreground stars
        ]

        for layer in layers {
            for _ in 0..<layer.count {
                let star = SKShapeNode(circleOfRadius: CGFloat.random(in: layer.sizeRange))
                star.fillColor = .white
                star.strokeColor = .clear
                star.alpha = layer.alpha
                star.position = CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )
                // Subtle twinkling
                let fade = SKAction.sequence([
                    SKAction.fadeAlpha(to: layer.alpha * 0.3, duration: Double.random(in: 2...5)),
                    SKAction.fadeAlpha(to: layer.alpha, duration: Double.random(in: 2...5))
                ])
                star.run(SKAction.repeatForever(fade))
                addChild(star)
            }
        }
    }
}
