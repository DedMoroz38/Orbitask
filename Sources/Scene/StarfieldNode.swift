import SpriteKit

// MARK: - Individual drifting star

private class StarDriftNode: SKShapeNode {
    /// Pixels-per-second velocity
    var driftVelocity: CGVector
    /// Radians-per-second curvature (keeps direction rotating slowly → arc)
    let driftCurvature: CGFloat
    let baseAlpha: CGFloat

    init(radius: CGFloat, velocity: CGVector, curvature: CGFloat, baseAlpha: CGFloat) {
        self.driftVelocity  = velocity
        self.driftCurvature = curvature
        self.baseAlpha      = baseAlpha
        super.init()
        let p = CGMutablePath()
        p.addArc(center: .zero, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        path         = p
        fillColor    = .white
        strokeColor  = .clear
        alpha        = baseAlpha
    }
    required init?(coder: NSCoder) { fatalError() }

    func step(in size: CGSize, dt: CGFloat) {
        // Curve the direction
        let speed = sqrt(driftVelocity.dx * driftVelocity.dx + driftVelocity.dy * driftVelocity.dy)
        let angle = atan2(driftVelocity.dy, driftVelocity.dx) + driftCurvature * dt
        driftVelocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)

        position.x += driftVelocity.dx * dt
        position.y += driftVelocity.dy * dt

        // Wrap around so stars flow continuously
        let m: CGFloat = 6
        if position.x < -m        { position.x = size.width  + m }
        else if position.x > size.width  + m { position.x = -m }
        if position.y < -m        { position.y = size.height + m }
        else if position.y > size.height + m { position.y = -m }
    }
}

// MARK: - Starfield

class StarfieldNode: SKNode {
    private var driftStars: [StarDriftNode] = []
    private var fieldSize: CGSize = .zero

    func populate(in size: CGSize) {
        // Cancel any pending shooting-star timers on self
        removeAllActions()
        removeAllChildren()
        driftStars.removeAll()
        fieldSize = size

        // layer: (count, radius, alpha range, speed px/s, curvature rad/s)
        let layers: [(Int, ClosedRange<CGFloat>, ClosedRange<CGFloat>, ClosedRange<CGFloat>, ClosedRange<CGFloat>)] = [
            (110, 0.5...1.0, 0.18...0.32,  0.8...3.5, 0.001...0.008),  // distant, very slow
            ( 55, 1.0...2.0, 0.38...0.55,  2.5...7.0, 0.002...0.012),  // mid-range
            ( 20, 1.5...3.0, 0.60...0.85,  6.0...14.0, 0.003...0.018), // bright foreground
        ]

        for (count, radRange, alphaRange, speedRange, curvRange) in layers {
            for _ in 0..<count {
                let base   = CGFloat.random(in: alphaRange)
                let speed  = CGFloat.random(in: speedRange)
                let angle0 = CGFloat.random(in: 0...(2 * .pi))
                let vel    = CGVector(dx: cos(angle0) * speed, dy: sin(angle0) * speed)
                let curve  = CGFloat.random(in: curvRange) * (Bool.random() ? 1 : -1)

                let star = StarDriftNode(
                    radius:     CGFloat.random(in: radRange),
                    velocity:   vel,
                    curvature:  curve,
                    baseAlpha:  base
                )
                star.position = CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )

                // Calm, slow flicker
                let flickerPeriod = Double.random(in: 4...10)
                let dimAlpha      = base * CGFloat.random(in: 0.25...0.50)
                let flicker = SKAction.sequence([
                    SKAction.fadeAlpha(to: dimAlpha, duration: flickerPeriod * 0.5),
                    SKAction.fadeAlpha(to: base,     duration: flickerPeriod * 0.5)
                ])
                star.run(SKAction.repeatForever(flicker))

                addChild(star)
                driftStars.append(star)
            }
        }

        scheduleShootingStar()
    }

    /// Called every frame from CosmicScene.update()
    func update(dt: TimeInterval) {
        let dtF = CGFloat(max(dt, 0.001))
        for star in driftStars {
            star.step(in: fieldSize, dt: dtF)
        }
    }

    // MARK: - Shooting Star

    private func scheduleShootingStar() {
        let delay = Double.random(in: 5...18)
        run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.run { [weak self] in self?.spawnShootingStar() }
        ]))
    }

    private func spawnShootingStar() {
        guard fieldSize != .zero else { scheduleShootingStar(); return }
        let w = fieldSize.width, h = fieldSize.height

        // Random travel direction
        let angle  = CGFloat.random(in: 0...(2 * .pi))
        let dx = cos(angle), dy = sin(angle)

        // Random start inside the central 70% of the screen
        let startX = CGFloat.random(in: w * 0.15...w * 0.85)
        let startY = CGFloat.random(in: h * 0.15...h * 0.85)
        let start  = CGPoint(x: startX, y: startY)

        // Distance to screen edge in travel direction
        let maxDist = distanceToEdge(from: start, direction: CGVector(dx: dx, dy: dy))
        // Stop at 55–78% of that distance so star never leaves the screen
        let travelDist = maxDist * CGFloat.random(in: 0.55...0.78)

        let speed    = CGFloat.random(in: 360...900)
        let duration = Double(travelDist / speed)
        let endPt    = CGPoint(x: start.x + dx * travelDist,
                               y: start.y + dy * travelDist)

        // Streak length — the trailing tail in local coords along -X axis
        let streakLen = CGFloat.random(in: 45...130)
        let streakPath = CGMutablePath()
        streakPath.move(to: CGPoint(x: -streakLen, y: 0))
        streakPath.addLine(to: .zero)

        let streak = SKShapeNode(path: streakPath)
        streak.position     = start
        streak.zRotation    = angle
        streak.strokeColor  = NSColor.white
        streak.lineWidth    = CGFloat.random(in: 1.0...2.0)
        streak.glowWidth    = 4.0
        streak.alpha        = 0
        streak.zPosition    = -5
        addChild(streak)

        // Fade-in fast, travel, begin fading ~0.25 s before arrival
        let fadeInDur  = 0.07
        let peakAlpha  = CGFloat.random(in: 0.7...0.95)
        let fadeOutDur = min(0.25, duration * 0.35)
        let waitBeforeFade = max(0, duration - fadeOutDur)

        let travelWithFade = SKAction.group([
            SKAction.move(to: endPt, duration: duration),
            SKAction.sequence([
                SKAction.wait(forDuration: waitBeforeFade),
                SKAction.fadeAlpha(to: 0, duration: fadeOutDur)
            ])
        ])

        streak.run(SKAction.sequence([
            SKAction.fadeAlpha(to: peakAlpha, duration: fadeInDur),
            travelWithFade,
            SKAction.removeFromParent()
        ]))

        scheduleShootingStar()
    }

    private func distanceToEdge(from point: CGPoint, direction: CGVector) -> CGFloat {
        let w = fieldSize.width, h = fieldSize.height
        var t = CGFloat.infinity
        if direction.dx > 0 { t = min(t, (w - point.x) / direction.dx) }
        else if direction.dx < 0 { t = min(t, -point.x / direction.dx) }
        if direction.dy > 0 { t = min(t, (h - point.y) / direction.dy) }
        else if direction.dy < 0 { t = min(t, -point.y / direction.dy) }
        return max(t, 0)
    }
}
