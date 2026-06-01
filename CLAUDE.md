# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

CosmicTasks is a macOS menu bar app (no Dock icon) that renders tasks as meteors orbiting a planet directly on the desktop wallpaper layer. Built with Swift 5.9, SpriteKit, and SwiftUI targeting macOS 14+.

## Build & Run

**First-time setup (generates Xcode project):**
```bash
./setup.sh          # installs xcodegen if needed, generates .xcodeproj, opens Xcode
```
Then press **⌘R** in Xcode to build and run.

**Headless universal binary build (no Xcode needed):**
```bash
./build.sh          # compiles arm64 + x86_64, lipo-merges, ad-hoc signs, launches the app
```

**Build a distributable DMG:**
```bash
./build_dmg.sh      # runs build.sh then packages into build/CosmicTasks.dmg
```

**Regenerate the Xcode project after editing `project.yml`:**
```bash
xcodegen generate
```

There is no test suite.

## Architecture

### Desktop Integration
`AppDelegate` creates one transparent borderless `NSWindow` per screen at `CGWindowLevelForKey(.desktopWindow) + 1` — above wallpaper, below all app windows. The window has `ignoresMouseEvents = true`; mouse events are captured via both global and local `NSEvent` monitors and forwarded to the relevant `CosmicScene` by converting global screen coordinates to per-window local coordinates.

### Data Flow
`TaskManager.shared` is the single source of truth — a singleton `ObservableObject` that persists `[CosmicTask]` as ISO-8601 JSON to `~/Library/Application Support/CosmicTasks/tasks.json`. After every mutation it posts either `.tasksDidChange` or `.taskCompleted` on `NotificationCenter`. `CosmicScene` observes these notifications and reconciles its `[UUID: MeteorNode]` dictionary accordingly.

### Orbital Positioning
`CosmicTask.urgency(horizon:)` returns `0.0` (far deadline) → `1.0` (overdue/now). `CosmicScene` maps this linearly from `Cosmic.outerOrbit` (urgency 0) to `Cosmic.innerOrbit` (urgency 1). New meteors are placed at the angle that maximises minimum distance to all existing meteors (`bestAngle` in `CosmicScene`).

### Interaction Model
- **Hover** over a meteor → `TaskPopoverNode` (read-only info card)
- **Click** a meteor → `TaskEditPopoverNode` (complete / delete / open link)
- **Drag from planet** → release on a meteor to fire a laser and complete the task

Both popover types use `computePopoverAnchor` to choose above/right/left/below placement that stays within scene bounds.

### SwiftC Compile Order
`build.sh` compiles sources in this fixed order (required due to no module system):
`Models → Helpers → Scene (StarfieldNode → PlanetNode → MeteorNode → ExplosionEffect → TaskPopoverNode → CosmicScene) → App (StatusBarController → AppDelegate → main)`

When adding new source files, update the `swiftc` invocations in `build.sh` for both `arm64` and `x86_64` targets, preserving this dependency order. Also update `project.yml` so `xcodegen generate` picks up the new file.
