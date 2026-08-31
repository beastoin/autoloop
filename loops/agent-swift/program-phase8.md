# Phase 9: idb Transport for iOS Simulator

## Context

Phase 8 added iOS Simulator support (`connect --sim`, simctl screenshot, coordinate-mapped click) but three frictions remain:

1. **No element discovery** — `snapshot` in simulator mode fails because it relies on macOS Accessibility (AXUIElement) which reads the Simulator.app window, not the iOS app inside.
2. **No text input** — `fill` requires AX to locate and set value on a text field.
3. **No swipe/scroll** — `scroll` requires AX scroll actions.
4. **AX trust dependency for click** — even coordinate-based `click` uses CGEvent through the macOS window, which depends on Simulator.app's AX-accessible window position.

All of these are solved by idb (iOS Development Bridge), which communicates directly with the iOS Simulator runtime via CoreSimulator, bypassing macOS Accessibility entirely.

## Prerequisite

`idb` (Python CLI) and `idb_companion` must be installed on the Mac. Agent-swift wraps the `idb` CLI via Process, same pattern as `xcrun simctl`.

Before first use, accessibility must be enabled inside the simulator:
```
xcrun simctl spawn <UDID> defaults write com.apple.Accessibility ApplicationAccessibilityEnabled -bool true
```

## Tracks

### Track 1: IdbBridge module

Create `Sources/AgentSwiftLib/Simulator/IdbBridge.swift`:

- `IdbError` enum with codes: `IDB_NOT_FOUND`, `IDB_COMMAND_FAILED`, `IDB_PARSE_FAILED`, `IDB_ACCESSIBILITY_DISABLED`
- `IdbElement` struct with: `type`, `role`, `label`, `value`, `frame` (CGRect), `uniqueId`, `enabled`, `children`
- `IdbBridge` struct wrapping `idb` CLI:
  - `describeAll(udid:)` → `[IdbElement]` — runs `idb ui describe-all --udid <udid> --nested --json`, parses result
  - `tap(x:y:udid:)` — runs `idb ui tap x y --udid <udid>`
  - `text(input:udid:)` — runs `idb ui text "input" --udid <udid>`
  - `swipe(from:to:udid:duration:)` — runs `idb ui swipe x1 y1 x2 y2 --udid <udid>`
  - `enableAccessibility(udid:)` — runs `xcrun simctl spawn` to set `ApplicationAccessibilityEnabled`
  - `isIdbAvailable()` → `Bool` — checks `which idb` succeeds
  - `runIdb(_:)` — Process wrapper for `idb` CLI (similar to `runSimctl`)

### Track 2: Simulator snapshot via idb

In simulator mode, `snapshot` command uses `IdbBridge.describeAll()` instead of AXClient tree walk:
- Parse `IdbElement` tree into the existing snapshot format (assign @eN refs, format as human/JSON output)
- The element tree uses iOS logical points directly (no coordinate mapping needed for display)
- `SnapshotFormatter` must handle IdbElement alongside AXClient's element model
- Ref-based commands (`press`, `fill`, `get`, `find`, `is`, `wait`) resolve refs against the idb snapshot

### Track 3: Simulator press/click via idb

- `press @eN` in simulator mode: resolve ref center point from IdbElement frame, call `IdbBridge.tap()`
- `click x y` in simulator mode: call `IdbBridge.tap()` directly (no CGEvent, no coordinate mapping needed — idb uses iOS points)
- `click @eN` in simulator mode: same as press — resolve center and tap

### Track 4: Simulator fill via idb

- `fill @eN "text"` in simulator mode: tap element center to focus, then call `IdbBridge.text()`
- Falls back to just text input if no ref is provided (for pre-focused fields)

### Track 5: Simulator scroll via idb

- `scroll up/down/left/right` in simulator mode: translate direction to swipe coordinates and call `IdbBridge.swipe()`
- `scroll @eN` (scroll element into view): calculate target position and swipe to reveal

### Track 6: Auto-enable accessibility on connect

- `connect --sim` auto-runs `enableAccessibility()` so `describe-all` works immediately
- Store `idbAvailable: Bool` in SessionStore for runtime checks
- Doctor command shows idb status when in simulator mode

### Track 7: Remove AX dependency in simulator mode

- In simulator mode, no macOS AX APIs are used (no AXUIElement, no CGEvent)
- `doctor` in sim mode: skip AX trust check, check idb availability instead
- All coordinate math uses iOS logical points directly (no window-to-screen mapping)

### Track 8: Tests

- `IdbTests.swift` with ≥ 15 test cases:
  - Parse idb describe-all JSON output (nested, flat, empty, single element)
  - IdbElement frame extraction and center point calculation
  - Direction-to-swipe coordinate mapping
  - Error handling (idb not found, parse failure)
  - IdbBridge.isIdbAvailable() with mock
  - Accessibility enable command construction
  - Session idbAvailable field serialization
- Existing tests remain green (backwards compat)

## Acceptance Criteria

1. `connect --sim` auto-enables accessibility inside simulator
2. `snapshot -i` in sim mode returns full element tree with @eN refs via idb
3. `press @eN` in sim mode taps the element via idb (no AX, no CGEvent)
4. `click x y` in sim mode taps via idb (no CGEvent coordinate mapping)
5. `fill @eN "text"` in sim mode inputs text via idb
6. `scroll down` in sim mode swipes via idb
7. `doctor` in sim mode checks idb availability, skips AX trust
8. All existing desktop-mode commands work unchanged
9. Version is 0.4.0
10. ≥ 95 tests pass (85 existing + 10 new minimum)
11. `IdbBridge.swift` exists with `describeAll`, `tap`, `text`, `swipe` methods
12. `IdbTests.swift` exists with ≥ 15 assertions
