import Cocoa
import SpriteKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var desktopWindow: NSWindow!
    var statusBarController: StatusBarController!
    var cosmicScene: CosmicScene!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupDesktopWindow()
        statusBarController = StatusBarController(scene: cosmicScene)
    }

    private func setupDesktopWindow() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame

        // Create a borderless, transparent window at the desktop level
        desktopWindow = NSWindow(
            contentRect: screenRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Pin to desktop level — below all normal windows, above the wallpaper
        desktopWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        desktopWindow.isOpaque = false
        desktopWindow.backgroundColor = .clear
        desktopWindow.hasShadow = false
        desktopWindow.ignoresMouseEvents = false
        desktopWindow.acceptsMouseMovedEvents = true

        // Appear on all Spaces (desktops) and stay stationary
        desktopWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Set up the SpriteKit view
        let skView = SKView(frame: screenRect)
        skView.allowsTransparency = true
        skView.autoresizingMask = [.width, .height]
        // skView.showsFPS = true  // Uncomment for debugging
        // skView.showsNodeCount = true

        cosmicScene = CosmicScene(size: screenRect.size)
        cosmicScene.scaleMode = .resizeFill
        cosmicScene.backgroundColor = .clear

        skView.presentScene(cosmicScene)
        desktopWindow.contentView = skView

        desktopWindow.orderFront(nil)

        // Watch for screen changes (resolution, display)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenDidChange(_ notification: Notification) {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        desktopWindow.setFrame(screenRect, display: true)
        cosmicScene.size = screenRect.size
    }
}
