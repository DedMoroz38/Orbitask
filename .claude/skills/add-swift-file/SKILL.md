---
name: add-swift-file
description: "Add a new Swift source file and wire it into build.sh (both archs) and project.yml correctly"
trigger: /add-swift-file
---

# /add-swift-file

Adding a Swift file to this project requires updating three places: the file itself, both `arm64` and `x86_64` compile lists in `build.sh`, and the sources list in `project.yml`. This skill does all three atomically.

## Usage

```
/add-swift-file Sources/Scene/MyNewNode.swift
/add-swift-file Sources/Views/MyView.swift
```

The path argument is relative to the project root.

## Compile Order Rules

`build.sh` must compile sources in this exact dependency order:

```
Models/     (CosmicTask.swift, TaskManager.swift)
Helpers/    (Constants.swift)
Scene/      (StarfieldNode → PlanetNode → MeteorNode → ExplosionEffect → TaskPopoverNode → CosmicScene)
App/Views/  (any SwiftUI views — before App/)
App/        (StatusBarController → AppDelegate → main)
```

When placing the new file:
- `Sources/Models/`   → after existing Models files
- `Sources/Helpers/`  → after existing Helpers files
- `Sources/Scene/`    → before `CosmicScene.swift` (unless it IS a scene orchestrator)
- `Sources/Views/`    → after Scene, before App/
- `Sources/App/`      → before `AppDelegate.swift` and `main.swift`

## What You Must Do When Invoked

1. Create the file at the given path with a minimal placeholder (correct Swift boilerplate for the type — `SKNode` subclass, `View`, `struct`, etc.).

2. Read `build.sh` and locate both `arm64` and `x86_64` `swiftc` invocations (they mirror each other). Insert the new path in the correct position in **both** invocations.

3. Read `project.yml`. The `sources` key lists `Sources/` — XcodeGen picks up files automatically from that directory, so no change is needed there. However, if the file is in a new subdirectory, verify the directory is covered by the glob.

4. Run `/build` to confirm the new file compiles cleanly.

5. Report: file created at `<path>`, inserted at position N in both arch sections of `build.sh`.

## Notes

- Never use `git add -A` — only stage the specific files you created/modified.
- If the new file depends on a type defined later in the compile order, move that dependency earlier or extract it to `Helpers/`.
