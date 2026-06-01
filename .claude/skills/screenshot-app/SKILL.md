---
name: screenshot-app
description: "Build, launch CosmicTasks, wait for the scene to render, capture the desktop, show the result"
trigger: /screenshot-app
---

# /screenshot-app

Build the app, let it render, take a screenshot of the primary display (which shows the planet + meteors on the wallpaper layer), and display it inline. Useful for visually verifying a change without switching to the desktop manually.

## Usage

```
/screenshot-app                     # full build + screenshot
/screenshot-app --no-build          # skip build, screenshot whatever is already running
/screenshot-app --delay 3           # wait N seconds after launch before capturing (default 2)
/screenshot-app --display 1         # capture display index 1 instead of main (0-indexed)
```

## What You Must Do When Invoked

1. Unless `--no-build` was passed, kill any running instance and build:
   ```bash
   pkill -x CosmicTasks 2>/dev/null; sleep 0.3
   cd /Users/egormaksimov/Documents/PROGRAMMING/taskeroid && ./build.sh
   ```
   Stop and report errors if the build fails.

2. Wait for the app to render. Default delay is 2 seconds; use `--delay N` if passed:
   ```bash
   sleep 2
   ```

3. Capture the primary display (or the display index from `--display`):
   ```bash
   screencapture -x /tmp/cosmictasks_screenshot.png
   ```
   (`-x` suppresses the shutter sound.)

4. Read the screenshot with the Read tool and display it to the user.

5. Report: display dimensions captured, file size, whether any meteors are visible (rough check: if the planet image region is visible the scene rendered correctly).

## Notes

- `screencapture` captures the full display including the wallpaper layer, which is where CosmicTasks renders. This is the only reliable way to verify the desktop overlay without switching focus.
- If the screen is locked or the display is asleep, `screencapture` will return a black frame — warn the user.
- For multi-monitor setups, use `screencapture -D <index>` to target a specific display. List available displays with `system_profiler SPDisplaysDataType | grep "Resolution"`.
- The screenshot captures the live desktop, so any other windows or system UI will appear in the capture.
