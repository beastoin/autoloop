# Phase 11: CGEvent-based Simulator Interaction

## Problem

In sim mode, `click`, `press`, `scroll`, and `fill` all go through idb. iOS keyboard extensions (and other cross-process UI) run in a separate process, so idb cannot see or interact with them. Users must manually calculate macOS screen coordinates and use cliclick — a 5-minute manual test takes 45+ minutes.

## Solution

Add CGEvent-based tap and swipe to SimulatorBridge, using the same pattern as MirrorBridge. CGEvent clicks on the Simulator window's macOS pixels regardless of which iOS process renders them. This bypasses idb's process boundary limitation.

## Tracks

### Track 1: SimulatorBridge CGEvent methods
- Add `tap(x: Double, y: Double)` to SimulatorBridge — maps iOS coordinates to macOS screen coordinates via `windowInfo()` + `iosPointToScreen()`, then CGEvent click
- Add `swipe(fromX:fromY:toX:toY:duration:)` to SimulatorBridge — CGEvent drag through Simulator window with interpolated path
- Add `activateSimulator()` private helper — bring Simulator window to front before CGEvent
- Add `directionToSwipeCoords()` to SimulatorBridge (same as MirrorBridge pattern)
- Add `screenshotWindow(to:)` — CGWindowListCreateImage on Simulator window (for cases where simctl screenshot is unavailable)

### Track 2: Wire CGEvent into click command
- `click x y` in sim mode uses SimulatorBridge.tap() (CGEvent through window) instead of idb.tap()
- `click @ref` in sim mode still uses idb.tap() first (since the ref was discovered by idb)
- JSON output includes iosPoint + screenPoint (same as mirror mode)

### Track 3: Wire CGEvent into scroll command
- `scroll up/down/left/right` in sim mode uses SimulatorBridge.swipe() (CGEvent) instead of idb.swipe()
- Same direction-to-coords mapping as mirror mode

### Track 4: Wire CGEvent into press command
- `press @ref` in sim mode: after idb tap, add CGEvent fallback through Simulator window using ref bounds

### Track 5: Version and tests
- Bump version to 0.6.0
- Add SimWindowTests.swift or extend SimulatorTests.swift with CGEvent method tests
- ≥ 130 total tests
- ≥ 10 new assertions for CGEvent sim methods

## Acceptance criteria

1. Version 0.6.0
2. SimulatorBridge has `tap(x:y:)` method (CGEvent)
3. SimulatorBridge has `swipe(fromX:fromY:toX:toY:duration:)` method (CGEvent)
4. SimulatorBridge has `directionToSwipeCoords()` method
5. `click x y` in sim mode uses CGEvent through Simulator window
6. `scroll` in sim mode uses CGEvent swipe through Simulator window
7. `press @ref` in sim mode has CGEvent fallback
8. ≥ 130 tests pass
9. ≥ 10 new assertions for SimulatorBridge CGEvent methods
10. All existing tests continue to pass
11. JSON output for click in sim mode includes iosPoint + screenPoint
12. Backwards compatible — @ref-based operations still work via idb
