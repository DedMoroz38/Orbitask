import Cocoa
import SpriteKit

/// Shared constants for the cosmic scene.
enum Cosmic {
    // Planet
    static let planetRadius: CGFloat = 60.0
    static let planetGlowRadius: CGFloat = 90.0

    // Meteors
    static let meteorBaseSize: CGFloat = 100.0
    static let meteorMaxSize: CGFloat = 120.0

    // Orbit radii — meteors range from outerOrbit (urgency 0) to innerOrbit (urgency 1)
    static let innerOrbit: CGFloat = 100.0
    static let outerOrbit: CGFloat = 420.0

    // Animation
    static let meteorDriftSpeed: CGFloat = 0.4  // Points per second of gentle orbit drift
    static let trailLength: Int = 12

    // Timing
    static let updateInterval: TimeInterval = 30.0  // Refresh meteor positions every 30s

    // Colors
    static let planetColor = NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
    static let planetGlowColor = NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.3)
    static let backgroundColor = NSColor.clear

    static func priorityColor(_ priority: TaskPriority) -> NSColor {
        switch priority {
        case .low:      return NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
        case .medium:   return NSColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1.0)
        case .high:     return NSColor(red: 0.96, green: 0.26, blue: 0.21, alpha: 1.0)
        case .critical: return NSColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0)
        }
    }
}
