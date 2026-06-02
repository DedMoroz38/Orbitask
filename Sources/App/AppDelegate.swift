import Cocoa
import CoreGraphics
import Metal
import SpriteKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var desktopWindows: [(window: NSWindow, view: CosmicRenderView)] = []
    var statusBarController: StatusBarController!

    private var eventMonitors: [Any] = []
    private weak var activeDragScene: CosmicScene?
    private lazy var metalDevice: MTLDevice = MTLCreateSystemDefaultDevice()!

    func applicationDidFinishLaunching(_ notification: Notification) {
        rebuildWindows()
        statusBarController = StatusBarController(scene: desktopWindows.first!.view.cosmicScene)
        installEventMonitors()
        BackendClient.shared.connect()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeEventMonitors()
        desktopWindows.forEach { $0.view.stopRendering() }
    }

    // MARK: - Per-Screen Windows

    private func rebuildWindows() {
        desktopWindows.forEach { $0.view.stopRendering(); $0.window.orderOut(nil) }
        desktopWindows.removeAll()
        for screen in NSScreen.screens {
            desktopWindows.append(makeDesktopWindow(for: screen))
        }
    }

    private func makeDesktopWindow(for screen: NSScreen) -> (window: NSWindow, view: CosmicRenderView) {
        let rect = screen.frame

        // NOTE: do NOT pass `screen:` here — when set, AppKit interprets contentRect
        // relative to that screen's origin, double-offsetting a frame that already
        // contains the global origin. Place the window explicitly with setFrame instead.
        let win = NSWindow(
            contentRect: rect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        win.setFrame(rect, display: true)

        let view = CosmicRenderView(size: rect.size, device: metalDevice)

        win.contentView = view
        win.orderFront(nil)
        view.startRendering()

        return (window: win, view: view)
    }

    @objc private func screensChanged() {
        let currentScreens = NSScreen.screens
        let currentIDs = Set(currentScreens.compactMap { $0.displayID })
        let existingIDs = Set(desktopWindows.compactMap { $0.window.screen?.displayID })

        desktopWindows.removeAll {
            guard let id = $0.window.screen?.displayID else {
                $0.view.stopRendering(); $0.window.orderOut(nil); return true
            }
            if !currentIDs.contains(id) {
                $0.view.stopRendering(); $0.window.orderOut(nil); return true
            }
            return false
        }

        currentScreens
            .filter { screen in
                guard let id = screen.displayID else { return false }
                return !existingIDs.contains(id)
            }
            .forEach { desktopWindows.append(makeDesktopWindow(for: $0)) }

        // Resync frames of surviving windows — handles arrangement changes,
        // resolution changes, and main-display switching.
        for entry in desktopWindows {
            guard let screen = currentScreens.first(where: { $0.displayID == entry.window.screen?.displayID }),
                  entry.window.frame != screen.frame else { continue }
            entry.window.setFrame(screen.frame, display: true)
            entry.view.cosmicScene.size = screen.frame.size
            entry.view.startRendering()
        }
    }

    // MARK: - Global Mouse Monitors

    private func removeEventMonitors() {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors.removeAll()
    }

    private func installEventMonitors() {
        removeEventMonitors()
        let pairs: [(NSEvent.EventTypeMask, Bool)] = [
            (.mouseMoved, false), (.leftMouseDown, false), (.leftMouseDragged, false), (.leftMouseUp, false),
            (.mouseMoved, true),  (.leftMouseDown, true),  (.leftMouseDragged, true),  (.leftMouseUp, true)
        ]
        let handlers: [() -> Void] = [
            { [weak self] in self?.handleMove() },
            { [weak self] in self?.handleClick() },
            { [weak self] in self?.handleDrag() },
            { [weak self] in self?.handleMouseUp() },
            { [weak self] in self?.handleMove() },
            { [weak self] in self?.handleClick() },
            { [weak self] in self?.handleDrag() },
            { [weak self] in self?.handleMouseUp() }
        ]
        for (i, (mask, isLocal)) in pairs.enumerated() {
            if isLocal {
                if let m = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
                    handlers[i](); return event
                }) { eventMonitors.append(m) }
            } else {
                if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { _ in
                    handlers[i]()
                }) { eventMonitors.append(m) }
            }
        }
    }

    private func scenePoint(for screenPt: NSPoint, in entry: (window: NSWindow, view: CosmicRenderView)) -> CGPoint? {
        guard entry.window.frame.contains(screenPt) else { return nil }
        // Window coordinates (origin bottom-left, Y up) match SpriteKit scene coordinates
        // exactly when scaleMode=.resizeFill and scene.size=screen.frame.size.
        // Do NOT call view.convert() — CosmicRenderView is layer-backed (wantsLayer=true),
        // which would flip Y to top-left origin and break all hit tests.
        return entry.window.convertFromScreen(NSRect(origin: screenPt, size: .zero)).origin
    }

    private func handleMove() {
        let screenPt = NSEvent.mouseLocation
        for entry in desktopWindows {
            if let viewPt = scenePoint(for: screenPt, in: entry) {
                entry.view.cosmicScene.handleMouseAt(viewPt)
                return
            }
        }
    }

    private func handleClick() {
        let screenPt = NSEvent.mouseLocation
        for entry in desktopWindows {
            if let viewPt = scenePoint(for: screenPt, in: entry) {
                entry.view.cosmicScene.handleMouseDownAt(viewPt)
                return
            }
        }
    }

    private func handleDrag() {
        let screenPt = NSEvent.mouseLocation
        for entry in desktopWindows {
            if let viewPt = scenePoint(for: screenPt, in: entry) {
                activeDragScene = entry.view.cosmicScene
                entry.view.cosmicScene.handleMouseDraggedAt(viewPt)
                return
            }
        }
    }

    private func handleMouseUp() {
        let screenPt = NSEvent.mouseLocation
        for entry in desktopWindows {
            if let viewPt = scenePoint(for: screenPt, in: entry) {
                activeDragScene = nil
                entry.view.cosmicScene.handleMouseUpAt(viewPt)
                return
            }
        }
        activeDragScene?.cancelDrag()
        activeDragScene = nil
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
