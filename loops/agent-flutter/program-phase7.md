# agent-flutter Phase 7: System Dialog Dismiss + Coordinate Tap

Two bugs reported from E2E testing (kenji, 7/20 flows):

## Problem 1: System Dialog Blocker

Android system dialogs (Google location services, permissions) pop up over
the Flutter app and block Marionette interactions. Marionette can only see
Flutter widgets — system dialogs are native Android UI. No way to dismiss
them without ADB.

## Problem 2: Ref Expiry Between Commands

Snapshot element refs (`@eN`) go stale between commands even without
user-initiated mutation. Flutter's widget tree rebuilds aggressively
(animations, timers, state updates), causing `getInteractiveElements` to
return different element ordering. Users fall back to raw ADB `input tap`
with pixel coordinates.

## Requirements

### 1. `dismiss` command

Dismiss the topmost Android system dialog via ADB.

```bash
agent-flutter dismiss              # dismiss current dialog
agent-flutter dismiss --check      # check if a dialog is present (exit 0=yes, 1=no)
```

Implementation:
- Use `adb shell dumpsys window` to detect if the current focused window
  is NOT the Flutter app (indicates a system dialog or overlay)
- Dismiss via `adb shell input keyevent BACK` (keyevent 4)
- `--check` flag: just report whether a non-app window is focused
- Exit codes: 0 = dismissed (or dialog present for --check), 1 = no dialog, 2 = error
- JSON output: `{ "dismissed": true/false, "window": "..." }`

### 2. `tap` command

Tap at absolute screen coordinates via ADB, bypassing Marionette refs entirely.

```bash
agent-flutter tap 200 400          # tap at x=200, y=400 (physical pixels)
agent-flutter tap @e3              # tap at center of @e3's bounds (ref-based)
```

Implementation:
- Accept either `x y` coordinates or `@ref` as arguments
- When given `@ref`, compute center from bounds in session snapshot
- Execute via `adb shell input tap <x> <y>` (uses physical pixels)
- This bypasses Marionette entirely — works even when refs are stale
- Physical pixel conversion: multiply logical bounds by device pixel ratio
  (get from `adb shell wm density`)
- Exit codes: 0 = success, 2 = error
- JSON output: `{ "tapped": { "x": N, "y": N }, "method": "coordinates"|"ref" }`

### 3. Schema + docs updates

- Add `dismiss` and `tap` to command-schema.ts
- Add to CLI dispatch in cli.ts
- Update AGENTS.md command table
- Add contract test coverage

## Acceptance Criteria

- [ ] `agent-flutter dismiss` sends ADB BACK when non-app window is focused
- [ ] `agent-flutter dismiss --check` exits 0 when dialog present, 1 when not
- [ ] `agent-flutter tap 200 400` sends `adb shell input tap 200 400`
- [ ] `agent-flutter tap @e3` computes center of @e3 bounds and taps there
- [ ] Both commands support `--json` output
- [ ] Both commands appear in `agent-flutter schema` output
- [ ] Unit tests cover dismiss detection and tap coordinate computation
- [ ] Existing eval.sh gates still pass (no regressions)
- [ ] `agent-flutter --help` lists both new commands

## Non-goals

- Auto-dismiss before every command (too aggressive, can hide real issues)
- Changing how refs work in Marionette (fundamental limitation)
- Physical device density auto-detection (user provides coords in physical pixels)
