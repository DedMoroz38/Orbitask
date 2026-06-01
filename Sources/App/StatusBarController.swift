import Cocoa
import SwiftUI

/// Controls the menu bar status item and provides task management UI.
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    private weak var scene: CosmicScene?

    init(scene: CosmicScene) {
        super.init()
        self.scene = scene

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "CosmicTasks")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc func togglePopover() {
        if let panel = panel, panel.isVisible {
            panel.orderOut(nil)
            self.panel = nil
            return
        }

        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let menuView = MenuBarView(onClose: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
        })

        let hc = NSHostingController(rootView: menuView)
        hc.view.wantsLayer = true

        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 480
        let buttonFrameInScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let originX = buttonFrameInScreen.midX - panelWidth / 2
        let originY = buttonFrameInScreen.minY - panelHeight - 6

        let p = KeyablePanel(
            contentRect: NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        p.contentViewController = hc

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self, weak p] _ in
            guard let p = p, p.isVisible else { return }
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }

        p.orderFrontRegardless()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = p
    }

    @objc private func appDidResignActive() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
