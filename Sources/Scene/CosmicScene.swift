import SpriteKit
import Cocoa

/// The main SpriteKit scene that renders the cosmic task visualization on the desktop.
class CosmicScene: SKScene {
    private var planet: PlanetNode!
    private var starfield: StarfieldNode!
    private var meteorNodes: [UUID: MeteorNode] = [:]
    private var hoveredMeteor: MeteorNode?
    private var popoverNode: TaskPopoverNode?
    private var lastUpdateTime: TimeInterval = 0

    // Orbit ring guides
    private var orbitRings: [SKShapeNode] = []

    override func didMove(to view: SKView) {
        backgroundColor = .clear

        setupStarfield()
        setupPlanet()
        setupOrbitRings()
        loadMeteors()

        // Listen for task changes
        NotificationCenter.default.addObserver(self, selector: #selector(tasksDidChange), name: .tasksDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(taskWasCompleted(_:)), name: .taskCompleted, object: nil)

        // Enable mouse tracking
        view.window?.acceptsMouseMovedEvents = true

        // Add tracking area covering the full view
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard planet != nil else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        planet.position = center
        starfield.populate(in: size)
        setupOrbitRings()
    }

    // MARK: - Setup

    private func setupStarfield() {
        starfield = StarfieldNode()
        starfield.zPosition = -10
        starfield.populate(in: size)
        addChild(starfield)
    }

    private func setupPlanet() {
        planet = PlanetNode()
        planet.position = CGPoint(x: size.width / 2, y: size.height / 2)
        planet.zPosition = 10
        addChild(planet)
    }

    private func setupOrbitRings() {
        orbitRings.forEach { $0.removeFromParent() }
        orbitRings.removeAll()

        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // Draw subtle orbit guide rings
        let ringRadii: [CGFloat] = [
            Cosmic.innerOrbit,
            Cosmic.innerOrbit + (Cosmic.outerOrbit - Cosmic.innerOrbit) * 0.33,
            Cosmic.innerOrbit + (Cosmic.outerOrbit - Cosmic.innerOrbit) * 0.66,
            Cosmic.outerOrbit
        ]

        for radius in ringRadii {
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.position = center
            ring.strokeColor = NSColor.white.withAlphaComponent(0.04)
            ring.lineWidth = 0.5
            ring.fillColor = .clear
            ring.zPosition = 1
            addChild(ring)
            orbitRings.append(ring)
        }
    }

    // MARK: - Meteor Management

    private func loadMeteors() {
        let tasks = TaskManager.shared.activeTasks
        let existingIDs = Set(meteorNodes.keys)
        let taskIDs = Set(tasks.map { $0.id })

        // Remove meteors for deleted/completed tasks
        for id in existingIDs.subtracting(taskIDs) {
            meteorNodes[id]?.removeFromParent()
            meteorNodes[id] = nil
        }

        // Add new meteors
        for task in tasks where meteorNodes[task.id] == nil {
            let meteor = MeteorNode(task: task)
            meteor.zPosition = 20
            addChild(meteor)
            meteorNodes[task.id] = meteor

            // Fade in
            meteor.alpha = 0
            meteor.run(SKAction.fadeIn(withDuration: 0.5))
        }
    }

    @objc private func tasksDidChange() {
        loadMeteors()
    }

    @objc private func taskWasCompleted(_ notification: Notification) {
        guard let taskID = notification.object as? UUID,
              let meteor = meteorNodes[taskID] else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let color = Cosmic.priorityColor(meteor.task.priority)

        // Dismiss popover if shown for this meteor
        if hoveredMeteor?.task.id == taskID {
            dismissPopover()
        }

        meteorNodes[taskID] = nil

        ExplosionEffect.absorb(node: meteor, toward: center, color: color, in: self) {
            // Meteor already removed by the action
        }
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for (_, meteor) in meteorNodes {
            meteor.updatePosition(center: center, dt: dt)
        }
    }

    // MARK: - Mouse Handling

    override func mouseMoved(with event: NSEvent) {
        guard let view = self.view else { return }
        let locationInView = view.convert(event.locationInWindow, from: nil)
        let location = convertPoint(fromView: locationInView)

        // Find the closest meteor under the cursor
        var closestMeteor: MeteorNode?
        var closestDist: CGFloat = .greatestFiniteMagnitude

        for (_, meteor) in meteorNodes {
            let dist = location.distance(to: meteor.position)
            if dist < max(Cosmic.meteorMaxSize, 22.0) && dist < closestDist {
                closestDist = dist
                closestMeteor = meteor
            }
        }

        if closestMeteor !== hoveredMeteor {
            // Unhover previous
            hoveredMeteor?.setHighlighted(false)
            dismissPopover()

            // Hover new
            hoveredMeteor = closestMeteor
            hoveredMeteor?.setHighlighted(true)

            if let meteor = closestMeteor {
                showPopover(for: meteor)
            }
        }

        // Update popover position to follow meteor
        if let popover = popoverNode, let meteor = hoveredMeteor {
            popover.position = CGPoint(x: meteor.position.x, y: meteor.position.y + 30)
        }
    }

    // MARK: - Click to complete

    override func mouseDown(with event: NSEvent) {
        guard let view = self.view else { return }
        let locationInView = view.convert(event.locationInWindow, from: nil)
        let location = convertPoint(fromView: locationInView)

        // Check if we clicked on a meteor — don't complete on single click,
        // but pass click through to desktop if no meteor hit
        var hitMeteor: MeteorNode?
        for (_, meteor) in meteorNodes {
            let dist = location.distance(to: meteor.position)
            if dist < max(Cosmic.meteorMaxSize, 22.0) {
                hitMeteor = meteor
                break
            }
        }

        if hitMeteor == nil {
            // Pass click through to desktop
            self.view?.window?.ignoresMouseEvents = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.view?.window?.ignoresMouseEvents = false
            }
        }
    }

    // Double-click to mark complete
    override func mouseUp(with event: NSEvent) {
        guard event.clickCount == 2, let view = self.view else { return }
        let locationInView = view.convert(event.locationInWindow, from: nil)
        let location = convertPoint(fromView: locationInView)

        for (_, meteor) in meteorNodes {
            let dist = location.distance(to: meteor.position)
            if dist < max(Cosmic.meteorMaxSize, 22.0) {
                TaskManager.shared.complete(meteor.task.id)
                break
            }
        }
    }

    // MARK: - Popover

    private func showPopover(for meteor: MeteorNode) {
        dismissPopover()
        let pop = TaskPopoverNode(task: meteor.task)
        pop.position = CGPoint(x: meteor.position.x, y: meteor.position.y + 30)
        pop.zPosition = 200
        addChild(pop)
        popoverNode = pop

        pop.alpha = 0
        pop.setScale(0.8)
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        pop.run(appear)
    }

    private func dismissPopover() {
        guard let pop = popoverNode else { return }
        let disappear = SKAction.group([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.scale(to: 0.8, duration: 0.1)
        ])
        pop.run(SKAction.sequence([disappear, SKAction.removeFromParent()]))
        popoverNode = nil
    }
}
