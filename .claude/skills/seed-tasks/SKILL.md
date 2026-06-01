---
name: seed-tasks
description: "Write controlled test tasks to tasks.json so you can test specific visual states (urgency, priority, count)"
trigger: /seed-tasks
---

# /seed-tasks

Overwrite `~/Library/Application Support/CosmicTasks/tasks.json` with a known set of tasks so you can reproduce a specific visual state for testing. The running app reloads tasks via the `.tasksDidChange` notification within 30 s, or immediately on next launch.

## Usage

```
/seed-tasks                    # default set: one task per priority, spread across urgency range
/seed-tasks --preset crowded   # 12 tasks — tests bestAngle() placement and overlap avoidance
/seed-tasks --preset urgent    # 4 critical tasks all due within 1 hour — tests inner orbit crowding
/seed-tasks --preset empty     # empty array — tests the "no tasks" state
/seed-tasks --preset single    # one medium task due in 3 days — minimal state for popover testing
```

## What You Must Do When Invoked

1. Determine the preset (default if none given).

2. Build the task array as a Swift-compatible ISO-8601 JSON payload. All dates must be relative to **today's actual date** — compute them from `date -u +%Y-%m-%dT%H:%M:%SZ` at run time, not from a hard-coded string.

3. Write the JSON to the tasks file:
   ```bash
   mkdir -p "$HOME/Library/Application Support/CosmicTasks"
   # write the JSON (use Write tool, not echo, for the file content)
   ```

4. If CosmicTasks is running, it will pick up the changes within one update cycle. Tell the user whether the app is currently running (`pgrep -x CosmicTasks`).

## Default Preset (one per priority, spread urgency)

| Title | Priority | Due |
|-------|----------|-----|
| "Fix login bug" | critical | +2 hours |
| "Write release notes" | high | +1 day |
| "Update dependencies" | medium | +3 days |
| "Refactor onboarding" | low | +6 days |

## JSON Schema Reference

```json
[
  {
    "id": "<UUID>",
    "title": "string",
    "description": "string",
    "priority": "low|medium|high|critical",
    "dueDate": "2026-06-01T14:00:00Z",
    "link": "",
    "isCompleted": false,
    "createdAt": "2026-06-01T10:00:00Z"
  }
]
```

## Notes

- `priority` must match `TaskPriority` raw values exactly: `"low"`, `"medium"`, `"high"`, `"critical"`.
- Generate fresh UUIDs with `uuidgen` for each task — never reuse IDs across seed runs.
- The app will merge the loaded tasks with its in-memory state via `loadMeteors()` — existing meteors for IDs not in the new file will be removed.
