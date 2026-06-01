import Cocoa
import SpriteKit
import QuartzCore
import CoreVideo
import Metal

/// Renders a `CosmicScene` via `SKRenderer` into a raw `CAMetalLayer`, driven by a
/// per-display `CVDisplayLink`.
///
/// Why not MTKView / SKView:
///   - SKView: when two live on two displays, SpriteKit only services one render loop;
///     the other freezes.
///   - MTKView: `currentDrawable` is only valid inside its own internal draw cycle, so
///     driving it from an external timer yields a stale/nil drawable → frozen output
///     (while the scene clock keeps advancing, which is why fps looked fine but nothing
///     moved). Its vsync handling also contends across displays.
///
/// This view owns its `CAMetalLayer` and calls `nextDrawable()` explicitly each frame —
/// an independent drawable pool per display. A `CVDisplayLink` bound to the physical
/// display fires in sync with that display's actual refresh (handles ProMotion), so each
/// screen renders at its native rate with no cross-display contention.
final class CosmicRenderView: NSView {
    let cosmicScene: CosmicScene
    private let renderer: SKRenderer
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    private var displayLink: CVDisplayLink?
    private let frameLock = NSLock()
    private var pendingFrame = false

    /// Per-display render thread. Each view renders independently, so a blocked
    /// `nextDrawable()` on one display (e.g. when it's hidden behind a full-screen app
    /// and its drawables are never returned) only stalls itself — never the other display.
    private let renderQueue: DispatchQueue
    /// Captured at init so the background render thread never touches `self.layer`
    /// (an AppKit main-thread-only property). CAMetalLayer's own methods are bg-safe.
    private var renderLayer: CAMetalLayer?

    private var metalLayer: CAMetalLayer? { layer as? CAMetalLayer }

    init(size: CGSize, device: MTLDevice) {
        self.device = device
        self.cosmicScene = CosmicScene(size: size)
        cosmicScene.scaleMode = .resizeFill
        cosmicScene.backgroundColor = .clear

        self.renderer = SKRenderer(device: device)
        self.commandQueue = device.makeCommandQueue()!
        self.renderQueue = DispatchQueue(label: "com.cosmictasks.render.\(UUID().uuidString)",
                                         qos: .userInteractive)

        super.init(frame: CGRect(origin: .zero, size: size))

        renderer.scene = cosmicScene

        // Layer-backed view with a CAMetalLayer we own and present to directly.
        wantsLayer = true
        if let ml = metalLayer {
            ml.device = device
            ml.pixelFormat = .bgra8Unorm
            ml.framebufferOnly = false
            ml.isOpaque = false                          // transparent over wallpaper
            ml.backgroundColor = NSColor.clear.cgColor
            ml.presentsWithTransaction = false           // async, non-blocking present
            renderLayer = ml
        }
        autoresizingMask = [.width, .height]
        updateDrawableSize()

        // Scene setup (didMove never fires without an SKView presentation).
        cosmicScene.activate()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func makeBackingLayer() -> CALayer { CAMetalLayer() }

    // MARK: - Sizing (we must manage contentsScale / drawableSize ourselves)

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    private func updateDrawableSize() {
        guard let ml = metalLayer else { return }
        let scale = window?.backingScaleFactor ?? 2.0
        ml.contentsScale = scale
        let px = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        if px.width > 0, px.height > 0 { ml.drawableSize = px }
        if cosmicScene.size != bounds.size, bounds.width > 0, bounds.height > 0 {
            cosmicScene.size = bounds.size
        }
    }

    // MARK: - CVDisplayLink lifecycle

    /// Start a CVDisplayLink bound to the display this view's window currently lives on.
    func startRendering() {
        stopRendering()
        let displayID = (window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
            ?? CGMainDisplayID()

        var link: CVDisplayLink?
        guard CVDisplayLinkCreateWithCGDisplay(displayID, &link) == kCVReturnSuccess,
              let link = link else { return }

        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            self?.displayLinkFired()
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(link)
        displayLink = link
    }

    func stopRendering() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
    }

    /// Fired on the CVDisplayLink's background thread. Hand off to this view's private
    /// render queue, coalescing so frames never pile up if the queue is briefly busy
    /// (e.g. blocked in `nextDrawable()`).
    private func displayLinkFired() {
        frameLock.lock()
        if pendingFrame { frameLock.unlock(); return }
        pendingFrame = true
        frameLock.unlock()

        renderQueue.async { [weak self] in
            guard let self = self else { return }
            self.frameLock.lock(); self.pendingFrame = false; self.frameLock.unlock()
            self.renderFrame()
        }
    }

    // MARK: - Render (runs on renderQueue, NOT main)

    private func renderFrame() {
        guard let ml = renderLayer else { return }
        let drawableSize = ml.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0 else { return }

        // Acquire the drawable OUTSIDE the scene lock. This is the call that can block
        // for ~1s when the layer is hidden behind a full-screen app and its drawables
        // are never returned. Keeping it off the lock (and off main) means that stall
        // only affects this one display.
        guard let drawable = ml.nextDrawable(),
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = drawable.texture
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        rpd.colorAttachments[0].storeAction = .store

        // Serialize scene access against main-thread mouse/notification handlers.
        cosmicScene.sceneLock.lock()
        renderer.update(atTime: CACurrentMediaTime())
        let viewport = CGRect(origin: .zero, size: drawableSize)
        renderer.render(withViewport: viewport,
                        commandBuffer: commandBuffer,
                        renderPassDescriptor: rpd)
        cosmicScene.sceneLock.unlock()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    deinit { stopRendering() }
}
