# CosmicTasks — Architecture, Improvements & Roadmap

## What This Is

CosmicTasks is a macOS menu bar app that renders tasks as meteors orbiting a planet directly on the desktop wallpaper layer. No Dock icon; purely ambient. Built with Swift 5.9, SpriteKit (scene/nodes/animations), and SwiftUI (menu bar panel).

---

## Current Code Structure

```
Sources/
├── Helpers/
│   └── Constants.swift          (38 lines)  — Visual constants (sizes, radii, colors, speeds)
├── Models/
│   ├── CosmicTask.swift         (71 lines)  — Task data model + urgency computation
│   └── TaskManager.swift       (118 lines)  — Singleton CRUD + JSON persistence + notifications
├── Scene/
│   ├── CosmicScene.swift       (484 lines)  — SKScene orchestrator, mouse handling, popover lifecycle
│   ├── MeteorNode.swift        (273 lines)  — Per-task SKNode: sprite, flames, orbit position
│   ├── TaskPopoverNode.swift   (490 lines)  — Hover info card (TaskPopoverNode) + edit card (TaskEditPopoverNode)
│   ├── StarfieldNode.swift     (189 lines)  — Procedural parallax starfield + shooting stars
│   ├── PlanetNode.swift         (56 lines)  — Central planet sprite + glow/atmosphere animations
│   └── ExplosionEffect.swift    (64 lines)  — Particle burst + flash ring on task completion
└── App/
    ├── main.swift                (6 lines)  — Entry point (creates NSApplication + AppDelegate)
    ├── AppDelegate.swift        (169 lines) — Per-screen NSWindow creation + global event monitors
    └── StatusBarController.swift(865 lines) — Menu bar icon, floating NSPanel, all SwiftUI views
```

### Data Flow

```
User action (SwiftUI panel)
        │
        ▼
  TaskManager.shared       ← single source of truth, persists to JSON
        │
        │  posts Notification (.tasksDidChange / .taskCompleted)
        ▼
  CosmicScene              ← listens, reconciles [UUID: MeteorNode] dictionary
        │
        ▼
  MeteorNode               ← owns SKSpriteNode, two SKEmitterNodes, SKLabelNode
```

### Desktop Integration

`AppDelegate` opens one transparent borderless `NSWindow` per `NSScreen` at window level `CGWindowLevelForKey(.desktopWindow) + 1` (above wallpaper, below every app window). Windows have `ignoresMouseEvents = true`; input is captured by eight global `NSEvent` monitors. `AppDelegate` converts `NSEvent.mouseLocation` (screen coordinates) into per-scene coordinates and dispatches to the correct `CosmicScene`.

### Orbital Mechanics

`CosmicTask.urgency(horizon:)` maps `daysRemaining / 7` → `[0, 1]`. `CosmicScene` maps urgency linearly to orbit radius `[outerOrbit, innerOrbit]` = `[420, 150]`. Drift speed is `meteorDriftSpeed / orbitRadius` so inner meteors naturally lap outer ones (Kepler-like). `bestAngle()` scans 36 candidate positions and places a new meteor at the angle that maximises its minimum distance to all existing meteors.

### Interaction States

| State | Trigger | Visual | Data effect |
|-------|---------|--------|-------------|
| Hover | Mouse over meteor | `TaskPopoverNode` (info card), meteor scales ×1.3 | — |
| Click | Mouse down on meteor | `TaskEditPopoverNode` (action buttons), meteor scales ×1.5 | — |
| Laser | Mouse down on planet, drag, release on meteor | Animated bolt + trail | `TaskManager.complete()` |
| Completion | `.taskCompleted` notification | `ExplosionEffect` particle burst + ring flash | Meteor removed |

---

## Issues & Bugs to Fix

### 1. Global event monitors are never removed

`AppDelegate.installEventMonitors()` registers eight monitors but never saves the return values, so they can't be removed. This leaks memory and can fire into a deallocated scene.

**Fix:** store all monitors in an array, call `NSEvent.removeMonitor()` on each in `applicationWillTerminate` and before each `rebuildWindows()` call.

```swift
// AppDelegate
private var eventMonitors: [Any] = []

func removeEventMonitors() {
    eventMonitors.forEach { NSEvent.removeMonitor($0) }
    eventMonitors.removeAll()
}

func installEventMonitors() {
    removeEventMonitors()
    if let m = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in self?.handleMove() }) {
        eventMonitors.append(m)
    }
    // … repeat for the other 7 monitors
}

func applicationWillTerminate(_ notification: Notification) {
    removeEventMonitors()
}
```

### 2. Silent JSON failures mask data loss

`TaskManager.save()` and `load()` use `try?` — any encode/decode failure silently falls back to demo tasks. A corrupted file loses all user data with no warning.

**Fix:** propagate errors, at minimum log them; on a read failure show the user an alert before wiping state.

```swift
func save() {
    do {
        let data = try encoder.encode(tasks)
        try data.write(to: fileURL, options: .atomicWrite)
    } catch {
        // surface to user or at minimum log
        print("[TaskManager] save failed: \(error)")
    }
}
```

### 3. `StatusBarController` is 865 lines — needs splitting

Every SwiftUI view (`MenuBarView`, `TaskRowView`, `AddTaskSheet`, `LiquidGlassPriorityPicker`, `CosmicDatePicker`, `CosmicTextField`) lives in one file alongside `StatusBarController` itself. This makes each view hard to find, test, or reuse.

**Fix:** one file per view. Extract into `Sources/Views/`:
```
Sources/Views/
├── MenuBarView.swift
├── TaskRowView.swift
├── AddTaskSheet.swift
├── LiquidGlassPriorityPicker.swift
├── CosmicDatePicker.swift
└── CosmicTextField.swift
```
Update `build.sh` compile order (all view files before `App/`) and add each to `project.yml`.

### 4. `TaskPopoverNode` and `TaskEditPopoverNode` share a file

Both classes are substantial (490 lines combined) and serve different interaction modes. Split into separate files: `TaskPopoverNode.swift` and `TaskEditPopoverNode.swift`.

### 5. Scene texture captured on every hover

`view?.texture(from:crop:)` renders the full scene to a texture on every `showPopover()` call. With many meteors and fast mouse movement this causes frame drops.

**Fix:** cache the background texture and invalidate it only when the scene layout changes (not on every hover):

```swift
private var cachedBackgroundTexture: SKTexture?
private var backgroundTextureDirty = true

func invalidateBackgroundCache() { backgroundTextureDirty = true }

func getBackgroundTexture() -> SKTexture? {
    if backgroundTextureDirty {
        cachedBackgroundTexture = view?.texture(from: self)
        backgroundTextureDirty = false
    }
    return cachedBackgroundTexture
}
```

Call `invalidateBackgroundCache()` after any meteor add/remove or window resize.

### 6. Flame particle colors diverge from `Constants.swift`

`MeteorNode.createFlameEmitter()` hard-codes a yellow→red gradient that doesn't reference `Cosmic.priorityColor()`. If priority colors are changed in `Constants.swift`, flames don't update.

**Fix:** pass the priority color into the gradient and derive surrounding stops from it:

```swift
func createFlameEmitter(priorityColor: NSColor, ...) {
    let seq = SKKeyframeSequence(...)
    seq.add(value: NSColor(red: 1, green: 0.92, blue: 0.45, alpha: 1), time: 0)
    seq.add(value: priorityColor, time: 0.25)
    seq.add(value: priorityColor.blended(withFraction: 0.5, of: .red) ?? .red, time: 0.65)
    seq.add(value: .clear, time: 1.0)
    // …
}
```

### 7. Date formatting is not localized

`"d MMM"` appears in multiple places. On non-English systems this still renders in the app's locale, not the user's.

**Fix:** use `DateFormatter` with `locale: .current` (which is already the default), and define one shared formatter in `Constants.swift` or a `Formatters.swift` helper so the format string lives in one place:

```swift
// Helpers/Formatters.swift
enum Formatters {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
```

### 8. `CosmicScene` has weak references to `desktopWindows` scenes but `AppDelegate` uses strong tuples

Each `(window: NSWindow, scene: CosmicScene)` tuple holds a strong reference. When `rebuildWindows()` clears the array, scenes are deallocated while their `SKView` is still alive. Move ownership to `SKView`/`SKScene` presentation and let SpriteKit manage lifetime.

---

## Multi-Display Support

The current multi-display implementation already creates one window per `NSScreen`, which is correct. However, there are several gaps:

### Gap 1: All scenes share one `TaskManager` but each renders independently

Right now each `CosmicScene` calls `loadMeteors()` independently, so meteors are duplicated on every screen. This is likely intentional (same tasks visible everywhere) but means click/hover handling on screen B could interfere with popover state on screen A.

**Recommended approach — one canonical scene, mirrored displays:**
- Designate the `mainScreen` (or whichever screen the status bar lives on) as the primary scene that handles all interaction.
- Secondary scenes render meteor positions read-only — no popovers, no event handling.
- `AppDelegate.handleClick()` already finds the window containing the cursor; extend this so only the primary scene shows popovers.

**Alternative — independent scenes per screen (current model, cleaned up):**
- Each scene has its own `hoveredMeteor`, `selectedMeteor`, `popoverNode`. This is already the case.
- The issue is `handleMouseAt()` dispatches to *all* scenes in `desktopWindows`; it should dispatch to only the scene whose window contains the cursor. Check `AppDelegate` — confirm only one scene receives each event.

### Gap 2: Planet is placed at scene center, which may not be the visual center on non-standard layouts

On ultra-wide or portrait monitors the scene center may not be visually appealing. Consider:

```swift
// CosmicScene
var preferredPlanetPosition: CGPoint {
    CGPoint(x: size.width * 0.5, y: size.height * 0.45) // slightly above center
}
```

Make this configurable per-screen in a future `ScreenConfig`.

### Gap 3: `screensChanged()` rebuilds all windows, losing all hover/popover state

`rebuildWindows()` is destructive: it hides existing windows, discards scenes, and creates fresh ones. During display changes (connecting a monitor, changing resolution) the app briefly loses all interactive state.

**Fix:** diff the screen list instead of rebuilding:

```swift
func screensChanged() {
    let currentScreens = Set(NSScreen.screens.map { $0.displayID })
    let existingScreens = Set(desktopWindows.map { $0.window.screen?.displayID })

    let added = currentScreens.subtracting(existingScreens)
    let removed = existingScreens.subtracting(currentScreens)

    removed.forEach { id in
        desktopWindows.removeAll { $0.window.screen?.displayID == id }
    }
    added.compactMap { id in NSScreen.screens.first { $0.displayID == id } }
         .forEach { screen in desktopWindows.append(makeDesktopWindow(for: screen)) }
}
```

(`NSScreen.displayID` requires `CGDirectDisplayID` from `CoreGraphics` — `screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID`)

### Gap 4: Mouse coordinate conversion is fragile across spaces and display arrangements

`NSEvent.mouseLocation` is in global screen coordinates, bottom-left origin. Each `NSWindow.frame` is also in global coordinates. The current conversion `window.frame.contains(globalPoint)` works but breaks if the menu bar or Dock changes height. Use `NSWindow.convertFromScreen(_:)` instead, which accounts for window insets:

```swift
let windowPoint = window.convertFromScreen(NSRect(origin: globalPoint, size: .zero)).origin
let viewPoint = view.convert(windowPoint, from: nil)
```

### Gap 5: `collectionBehavior` should include `.fullScreenAuxiliary` for external monitors in fullscreen mode

When a connected display is running a fullscreen app, windows with `.stationary` but without `.fullScreenAuxiliary` are hidden. Add:

```swift
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
```

---

## Claude Code Skills

Four project-local skills live in `.claude/skills/`. Invoke them with a `/` prefix in Claude Code.

### `/build` — [.claude/skills/build/SKILL.md](.claude/skills/build/SKILL.md)

Kills any running CosmicTasks instance, runs `./build.sh`, and surfaces Swift compiler errors grouped by file rather than dumping the raw log. Use this instead of running `build.sh` directly so errors are always presented consistently.

```
/build           # build and launch
/build --no-run  # compile only
```

**Why useful:** `build.sh` compiles arm64 and x86_64 separately, so each error appears twice in the raw output. The skill deduplicates them and offers to fix the first error automatically.

---

### `/add-swift-file` — [.claude/skills/add-swift-file/SKILL.md](.claude/skills/add-swift-file/SKILL.md)

Creates a new Swift source file and wires it into **both** architecture sections of `build.sh` at the correct compile-order position. This is the most common footgun in this project — forgetting to add a file to one of the two `swiftc` invocations causes a mysterious "undefined symbol" error only on one architecture.

```
/add-swift-file Sources/Scene/RingNode.swift
/add-swift-file Sources/Views/TaskRowView.swift
```

**Why useful:** `build.sh` has a fixed compile order (`Models → Helpers → Scene → Views → App`) and must be updated in two identical places. The skill knows the order rules and inserts the file correctly in both.

---

### `/seed-tasks` — [.claude/skills/seed-tasks/SKILL.md](.claude/skills/seed-tasks/SKILL.md)

Writes a controlled set of tasks to `~/Library/Application Support/CosmicTasks/tasks.json` so you can reproduce a specific visual state without manually adding tasks through the UI. The running app picks up the change within one update cycle (~30 s).

```
/seed-tasks                    # default: one task per priority across urgency range
/seed-tasks --preset crowded   # 12 tasks — tests bestAngle() and overlap avoidance
/seed-tasks --preset urgent    # 4 critical tasks due within 1 hour — tests inner orbit crowding
/seed-tasks --preset empty     # empty array — tests the no-tasks state
/seed-tasks --preset single    # one medium task — minimal state for popover testing
```

**Why useful:** urgency depends on `Date.now`, so you can't test specific orbit positions by editing the JSON by hand — the dates have to be computed relative to the current time. The skill does that automatically.

---

### `/screenshot-app` — [.claude/skills/screenshot-app/SKILL.md](.claude/skills/screenshot-app/SKILL.md)

Builds the app, waits for SpriteKit to render the first frame, captures the primary display with `screencapture`, and shows the image inline. The only reliable way to verify desktop overlay changes without switching away from the terminal.

```
/screenshot-app                  # build + screenshot
/screenshot-app --no-build       # screenshot whatever is already running
/screenshot-app --delay 3        # wait 3 s after launch before capturing
/screenshot-app --display 1      # capture a secondary monitor (0-indexed)
```

**Why useful:** CosmicTasks renders below all app windows — you can't see it in a simulator or with a normal UI test. This skill captures the actual wallpaper layer.

---

## Quick-Win Checklist

- [ ] Fix: store and remove all `NSEvent` monitors (critical — currently leaks)
- [ ] Fix: propagate JSON errors instead of swallowing them
- [ ] Fix: add `.fullScreenAuxiliary` to window `collectionBehavior`
- [ ] Fix: use `window.convertFromScreen` for mouse coordinates
- [ ] Refactor: split `StatusBarController.swift` into per-view files
- [ ] Refactor: split `TaskPopoverNode.swift` into two files
- [ ] Refactor: cache background texture, invalidate on layout change
- [ ] Refactor: derive flame gradient from `Cosmic.priorityColor()`
- [ ] Refactor: single shared `DateFormatter` in `Formatters.swift`
- [ ] Feature: diff-based `screensChanged()` to avoid full rebuild on display config change
- [ ] Feature: designate primary scene for popovers on multi-monitor setups
