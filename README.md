# CosmicTasks 🌌

An interactive productivity wallpaper for macOS. A planet sits at the center of your desktop, and every task is a meteor orbiting toward it — the closer the deadline, the closer the meteor.

![Concept](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![SpriteKit](https://img.shields.io/badge/SpriteKit-✓-green)

## How It Works

- **Desktop-level window**: The app creates an invisible, borderless `NSWindow` pinned at `CGWindowLevelForKey(.desktopWindow) + 1` — it sits directly on your desktop, below all normal windows, above the wallpaper. It does not appear in the Dock, Mission Control, or Cmd+Tab.
- **SpriteKit scene**: A transparent SpriteKit scene renders the planet, orbiting meteors, starfield, and particle effects.
- **Menu bar app**: A `✨` icon in the menu bar lets you add, view, and manage tasks. No separate window.

## Visual Design

| Element | Description |
|---------|-------------|
| 🪐 Planet | Glowing blue planet at screen center with atmosphere ring |
| ☄️ Meteors | Colored by priority: 🟢 low, 🟠 medium, 🔴 high, 🟣 critical |
| 📏 Orbit | Position = deadline urgency (0–100% of a 7-day horizon) |
| ✨ Stars | Layered starfield with twinkling animation |
| 💥 Completion | Meteor spirals into planet → explosion particle effect |
| 📋 Popover | Hover over any meteor to see title, description, priority, due date |

## Quick Start

```bash
./setup.sh
```

This will:
1. Install `xcodegen` if needed (via Homebrew)
2. Generate `CosmicTasks.xcodeproj`
3. Open it in Xcode

Then press **⌘R** to build and run.

### Manual Setup

```bash
brew install xcodegen   # if not already installed
xcodegen generate
open CosmicTasks.xcodeproj
```

## Usage

- **Menu bar icon** (✨): Click to open task management panel
- **Add tasks**: Click `+` in the panel, set title/description/priority/due date
- **Hover meteors**: Shows task details popover on the desktop
- **Double-click meteor**: Marks the task complete (spirals into planet + explosion)
- **Single-click empty space**: Click passes through to desktop normally

## Architecture

```
Sources/
├── App/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Desktop window setup
│   └── StatusBarController.swift  # Menu bar + SwiftUI task management
├── Models/
│   ├── CosmicTask.swift        # Task data model with urgency calculation
│   └── TaskManager.swift       # CRUD + JSON persistence
├── Scene/
│   ├── CosmicScene.swift       # Main SpriteKit scene orchestrator
│   ├── PlanetNode.swift        # Central planet with glow effects
│   ├── MeteorNode.swift        # Task meteor with trail particles
│   ├── StarfieldNode.swift     # Procedural starfield background
│   ├── TaskPopoverNode.swift   # Hover detail card (SpriteKit)
│   └── ExplosionEffect.swift   # Completion particle effects
└── Helpers/
    └── Constants.swift         # Shared visual constants
```

## Persistence

Tasks are stored as JSON in:
```
~/Library/Application Support/CosmicTasks/tasks.json
```

On first launch, demo tasks are seeded so you can see the visualization immediately.

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- Swift 5.9

## Key Implementation Details

| Feature | How |
|---------|-----|
| Desktop integration | `NSWindow.level = desktopWindow + 1`, borderless, transparent |
| No Dock icon | `LSUIElement = true` in Info.plist |
| All Spaces | `collectionBehavior = [.canJoinAllSpaces, .stationary]` |
| Click-through | Empty areas pass clicks to desktop; meteors intercept |
| 60fps animation | SpriteKit render loop with orbit drift |
| Urgency mapping | `urgency = 1 - (timeRemaining / 7days)`, clamped 0–1 |
