import SpriteKit
import Cocoa

/// The main SpriteKit scene that renders the cosmic task visualization on the desktop.
class CosmicScene: SKScene {
    private var planet: PlanetNode!
    private var starfield: StarfieldNode!
    private var meteorNodes: [UUID: MeteorNode] = [:]
    private var hoveredMeteor: MeteorNode?
    private var popoverNode: TaskPopoverNode?
    private var selectedMeteor: MeteorNode?
    private var editPopoverNode: TaskEditPopoverNode?
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

        // Dismiss popover if shown for this meteor
        if hoveredMeteor?.task.id == taskID {
            dismissPopover()
        }
        if selectedMeteor?.task.id == taskID {
            dismissEditPopover()
        }

        meteorNodes[taskID] = nil

        meteor.animateCompletion(toward: center, in: self) {}
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

        starfield.update(dt: dt)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for (_, meteor) in meteorNodes {
            meteor.updatePosition(center: center, dt: dt)
        }

        // Keep edit popover attached to its meteor using smart anchor
        if let ep = editPopoverNode, let m = selectedMeteor {
            let h = TaskEditPopoverNode.preferredHeight(for: m.task)
            ep.position = computePopoverAnchor(meteorPos: m.position,
                                               meteorRadius: m.meteorSize / 2,
                                               popoverWidth: 260, popoverHeight: h)
        }
    }

    // MARK: - Public Mouse Handlers (called from AppDelegate global monitors)

    func handleMouseAt(_ viewPoint: CGPoint) {
        let location = convertPoint(fromView: viewPoint)
        var closestMeteor: MeteorNode?
        var closestDist: CGFloat = .greatestFiniteMagnitude

        for (_, meteor) in meteorNodes {
            let dist = location.distance(to: meteor.position)
            if dist < meteor.meteorSize / 2 && dist < closestDist {
                closestDist = dist
                closestMeteor = meteor
            }
        }

        if closestMeteor !== hoveredMeteor {
            hoveredMeteor?.setHighlighted(false)
            dismissPopover()
            hoveredMeteor = closestMeteor
            hoveredMeteor?.setHighlighted(true)
            if let m = closestMeteor { showPopover(for: m) }
        }

        if let pop = popoverNode, let m = hoveredMeteor {
            let h = TaskPopoverNode.preferredHeight(for: m.task)
            pop.position = computePopoverAnchor(meteorPos: m.position,
                                                meteorRadius: m.meteorSize / 2,
                                                popoverWidth: 260, popoverHeight: h)
        }
    }

    func handleDoubleClickAt(_ viewPoint: CGPoint) {
        let location = convertPoint(fromView: viewPoint)
        for (_, meteor) in meteorNodes {
            if location.distance(to: meteor.position) < meteor.meteorSize / 2 {
                TaskManager.shared.complete(meteor.task.id)
                return
            }
        }
    }

    func handleClickAt(_ viewPoint: CGPoint) {
        let location = convertPoint(fromView: viewPoint)

        // If edit popover is open, check button hits first
        if let ep = editPopoverNode {
            if let action = ep.hitTest(scenePoint: location) {
                let taskID = ep.task.id
                switch action {
                case .complete:
                    dismissEditPopover()
                    TaskManager.shared.complete(taskID)
                case .delete:
                    dismissEditPopover()
                    TaskManager.shared.delete(taskID)
                }
                return
            }
            // Clicked outside the popover — dismiss it
            if !ep.containsScenePoint(location) {
                dismissEditPopover()
            }
            return
        }

        // Check if a meteor was clicked — open edit popover
        for (_, meteor) in meteorNodes {
            if location.distance(to: meteor.position) < meteor.meteorSize / 2 {
                showEditPopover(for: meteor)
                return
            }
        }
    }

    // MARK: - Popover Positioning

    /// Computes the best anchor (bottom-center of the popover card) so the popover
    /// does not overlap the meteor and stays inside the scene bounds.
    /// Preference order: above → right → left → below → clamped fallback.
    private func computePopoverAnchor(meteorPos: CGPoint,
                                      meteorRadius: CGFloat,
                                      popoverWidth w: CGFloat,
                                      popoverHeight h: CGFloat) -> CGPoint {
        let gap: CGFloat = 14
        let margin: CGFloat = 8

        let candidates: [CGPoint] = [
            // Above
            CGPoint(x: meteorPos.x, y: meteorPos.y + meteorRadius + gap),
            // Right (centered vertically)
            CGPoint(x: meteorPos.x + meteorRadius + gap + w / 2, y: meteorPos.y - h / 2),
            // Left (centered vertically)
            CGPoint(x: meteorPos.x - meteorRadius - gap - w / 2, y: meteorPos.y - h / 2),
            // Below
            CGPoint(x: meteorPos.x, y: meteorPos.y - meteorRadius - gap - h),
        ]

        for anchor in candidates {
            let rect = CGRect(x: anchor.x - w / 2, y: anchor.y, width: w, height: h)
            if rect.minX >= margin && rect.maxX <= size.width - margin &&
               rect.minY >= margin && rect.maxY <= size.height - margin {
                return anchor
            }
        }

        // Clamped fallback: above, pushed inside bounds
        var fallback = CGPoint(x: meteorPos.x, y: meteorPos.y + meteorRadius + gap)
        fallback.x = max(w / 2 + margin, min(size.width  - w / 2 - margin, fallback.x))
        fallback.y = max(margin,          min(size.height - h   - margin,   fallback.y))
        return fallback
    }

    // MARK: - Popover

    private func showPopover(for meteor: MeteorNode) {
        dismissPopover()
        let w = CGFloat(260)
        let h = TaskPopoverNode.preferredHeight(for: meteor.task)
        let anchor = computePopoverAnchor(meteorPos: meteor.position,
                                          meteorRadius: meteor.meteorSize / 2,
                                          popoverWidth: w, popoverHeight: h)
        let cropRect = CGRect(x: anchor.x - w / 2, y: anchor.y, width: w, height: h)
        let bgTex = view?.texture(from: self, crop: cropRect)

        let pop = TaskPopoverNode(task: meteor.task, backgroundTexture: bgTex)
        pop.position = anchor
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

    // MARK: - Edit Popover

    private func showEditPopover(for meteor: MeteorNode) {
        dismissEditPopover()
        dismissPopover()

        selectedMeteor?.setSelected(false)
        selectedMeteor = meteor
        meteor.setSelected(true)

        let w = CGFloat(260)
        let h = TaskEditPopoverNode.preferredHeight(for: meteor.task)
        let anchor = computePopoverAnchor(meteorPos: meteor.position,
                                          meteorRadius: meteor.meteorSize / 2,
                                          popoverWidth: w, popoverHeight: h)
        let cropRect = CGRect(x: anchor.x - w / 2, y: anchor.y, width: w, height: h)
        let bgTex = view?.texture(from: self, crop: cropRect)

        let ep = TaskEditPopoverNode(task: meteor.task, backgroundTexture: bgTex)
        ep.position = anchor
        ep.zPosition = 210
        addChild(ep)
        editPopoverNode = ep

        ep.alpha = 0
        ep.setScale(0.8)
        ep.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ]))
    }

    private func dismissEditPopover() {
        if let ep = editPopoverNode {
            let disappear = SKAction.group([
                SKAction.fadeOut(withDuration: 0.1),
                SKAction.scale(to: 0.8, duration: 0.1)
            ])
            ep.run(SKAction.sequence([disappear, SKAction.removeFromParent()]))
            editPopoverNode = nil
        }
        selectedMeteor?.setSelected(false)
        selectedMeteor = nil
    }
}
