# Phase 12: User-Driven UX — type, swipe, compound find, multi-sim

## Problem

ivy and sui both use agent-swift daily for VoxBoard iOS testing. Both independently report the same #1 gap: **no way to type text into a focused field**. sui built an entire programmatic workaround (DispatchQueue + layoutDidInsertText); ivy shells out to osascript. The second biggest gap is **arbitrary swipe/drag by coordinates** — ivy reaches for idb every time she needs to dismiss a sheet, scroll to an off-screen element, or swipe-to-type. Additional friction: sui can't disambiguate elements with the same text (`find text Open` hits title instead of button), can't select a specific simulator when multiple are booted, and clipped ScrollView elements are invisible to snapshot.

## Solution

Six features scoped directly from user feedback, ordered by pain:

1. **`type` command** — send keystrokes to focused field in sim mode
2. **`swipe` command** — arbitrary coordinate-based swipe gesture
3. **Compound locators** in `find` — filter by multiple attributes
4. **`connect --sim --udid <UDID>`** — explicit simulator selection
5. **`snapshot --all`** — include off-screen/clipped elements via idb accessibility
6. **Better discoverability** — `find --help` shows valid locator×action combos

## Tracks

### Track 1: type command
- Add `TypeCommand` — sends text to the currently focused field
- Sim mode: use `IdbBridge.text()` (already exists) to send keystrokes
- macOS AX mode: use `AXClient.performFill` on focused element
- Mirror mode: CGEvent key-by-key typing
- Usage: `agent-swift type "hello world"`
- JSON output: `{"typed": "hello world", "success": true}`
- Exit 0 on success, 2 on error
- Add `type` to schema command list

### Track 2: swipe command
- Add `SwipeCommand` — arbitrary coordinate-based swipe gesture
- Sim mode: use `SimulatorBridge.swipe(fromX:fromY:toX:toY:)` (CGEvent, already exists internally)
- Mirror mode: use `MirrorBridge.swipe()` (already exists)
- macOS AX mode: CGEvent drag
- Usage: `agent-swift swipe 200 400 200 100` (from x1 y1 to x2 y2)
- Optional `--duration <seconds>` flag (default 0.3)
- JSON output: `{"from": {x,y}, "to": {x,y}, "success": true}`
- Exit 0 on success, 2 on error
- Add `swipe` to schema command list

### Track 3: Compound locators in find
- Extend `FindCommand` to accept multiple locator pairs: `find role button text Open press`
- Parse as: `[locator1, value1, locator2, value2, ..., action]`
- Each locator pair narrows the match set (AND logic)
- Supported locators: `text`, `role`, `label`, `identifier`, `value`
- When multiple elements still match, show all with refs and ask user to pick (or use first)
- JSON output includes `matchCount` field

### Track 4: Multi-sim selection
- Add `--udid <UDID>` flag to `connect --sim`
- When `--udid` is provided, connect to that specific simulator
- When omitted, keep current behavior (first booted sim)
- Show available booted simulators in error message when UDID not found
- Store selected UDID in session

### Track 5: snapshot --all (off-screen elements)
- Add `--all` flag to `SnapshotCommand`
- In sim mode with `--all`: use `idb ui describe-all --nested` with accessibility flags that include off-screen elements
- Fall back to regular snapshot if enhanced mode fails
- Mark off-screen elements in output (e.g., `[offscreen]` tag)

### Track 6: Discoverability improvements
- Add extended help to `FindCommand` showing valid locator×action combinations
- Improve error messages: when user types `tap` suggest `press`, when user types `label` suggest `text`
- Add `--help-examples` or detailed help section to find

### Track 7: Version and tests
- Bump version to 0.7.0
- Add TypeTests, SwipeTests, CompoundFindTests
- ≥ 145 total tests
- ≥ 15 new assertions for new features

## Acceptance criteria

1. Version 0.7.0
2. `type "text"` command works in sim mode (sends to focused field)
3. `type` added to schema output
4. `swipe x1 y1 x2 y2` command works in sim mode (CGEvent)
5. `swipe` added to schema output
6. `find role button text Open press` compound locator works
7. `connect --sim --udid <UDID>` selects specific simulator
8. `snapshot --all` flag exists and includes more elements
9. `find --help` shows valid locator×action combinations
10. Error messages suggest correct command names for common typos
11. ≥ 145 tests pass
12. ≥ 15 new assertions for type/swipe/compound find
13. All existing tests continue to pass
14. Backwards compatible — all v0.6.0 commands unchanged
