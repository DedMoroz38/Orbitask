import Cocoa
import SpriteKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var desktopWindows: [(window: NSWindow, scene: CosmicScene)] = []
    var statusBarController: StatusBarController!

    // Global event monitors — fire regardless of which app is active
    private var globalMoveMonitor: Any?
    private var globalClickMonitor: Any?
    private var localMoveMonitor: Any?
    private var localClickMonitor: Any?

    // Double-click detection
    private var lastClickTime: TimeInterval = 0
    private var lastClickPos: CGPoint = .zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        rebuildWindows()
        statusBarController = StatusBarController(scene: desktopWindows.first!.scene)
        installEventMonitors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Per-Screen Windows

    private func rebuildWindows() {
        desktopWindows.forEach { $0.window.orderOut(nil) }
        desktopWindows.removeAll()
        for screen in NSScreen.screens {
            let pair = makeDesktopWindow(for: screen)
            desktopWindows.append(pair)
        }
    }

    private func makeDesktopWindow(for screen: NSScreen) -> (window: NSWindow, scene: CosmicScene) {
        let rect = screen.frame

        let win = NSWindow(
            contentRect: rect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true          // interaction via global monitors
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let skView = SKView(frame: CGRect(origin: .zero, size: rect.size))
        skView.allowsTransparency = true
        skView.autoresizingMask = [.width, .height]

        let scene = CosmicScene(size: rect.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        skView.presentScene(scene)

        win.contentView = skView
        win.orderFront(nil)
        return (window: win, scene: scene)
    }

    @objc private func screensChanged() {
        rebuildWindows()
    }

    // MARK: - Global Mouse Monitors

    private func installEventMonitors() {
        // Global monitors: other apps are active
        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMove()
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.handleClick()
        }
        // Local monitors: our own app is active (menu bar popover open, etc.)
        localMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMove()
            return event
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleClick()
            return event
        }
    }

    private func handleMove() {
        let screenPt = NSEvent.mouseLocation  // global screen coords
        for entry in desktopWindows {
            if entry.window.frame.contains(screenPt) {
                let viewPt = CGPoint(
                    x: screenPt.x - entry.window.frame.origin.x,
                    y: screenPt.y - entry.window.frame.origin.y
                )
                entry.scene.handleMouseAt(viewPt)
                return
            }
        }
    }

    private func handleClick() {
        let screenPt = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime
        let isDouble = (now - lastClickTime) < 0.35
            && lastClickPos.distance(to: screenPt) < 8
        lastClickTime = now
        lastClickPos = screenPt

        guard isDouble else { return }   // only react to double-click
        for entry in desktopWindows {
            if entry.window.frame.contains(screenPt) {
                let viewPt = CGPoint(
                    x: screenPt.x - entry.window.frame.origin.x,
                    y: screenPt.y - entry.window.frame.origin.y
                )
                entry.scene.handleDoubleClickAt(viewPt)
                return
            }
        }
    }
}
