# Phase 7: iOS Simulator Touch Transport for `agent-swift`

**Key Result: `agent-swift connect --simulator` connects to a booted iOS Simulator and enables touch interaction via `simctl` + coordinate-mapped input, so agents can automate iOS apps running in the Simulator.**

Build on the existing CLI in `loops/agent-swift/agent-swift` (all prior phases complete, 68+ tests, 15 commands).

## Before You Start

Read these files:
- `Sources/agent-swift/main.swift` — ConnectCommand, ClickCommand, ScreenshotCommand, PressCommand
- `Sources/AgentSwiftLib/AX/AXClient.swift` — performClick (CGEvent), walkTree, AXNode
- `Sources/AgentSwiftLib/Session/SessionStore.swift` — SessionData, RefEntry

## Problem

agent-swift can read the iOS Simulator's AX tree as a macOS app, but the AX tree exposes the Simulator window chrome — not the iOS app's UI elements. CGEvent clicks land on the Simulator window and ARE translated to touch events when coordinates are correct, but:
1. Coordinate mapping is non-trivial (toolbar offset, device bezel, scale factor)
2. `@eN` refs from a macOS AX snapshot point to Simulator chrome, not iOS elements
3. There's no element discovery for the iOS app content inside the Simulator

## Architecture

Two-mode session model:
- **Desktop mode** (existing): AX-based snapshot/press/click/fill against macOS apps
- **Simulator mode** (new): `simctl`-based screenshot + coordinate-mapped touch input

When connected in simulator mode:
- `screenshot` → `xcrun simctl io <udid> screenshot` (captures the iOS device screen, not the macOS window)
- `click x y` → CGEvent click at coordinates mapped from iOS logical points to Simulator window position
- `press @eN` → still uses AX for Simulator chrome elements (toolbar buttons, etc.)
- Session stores `simulatorUDID` and `simulatorWindowOrigin` / `simulatorContentScale`

## Scope

### Track 1: SimulatorBridge utility (P0)

New file: `Sources/AgentSwiftLib/Simulator/SimulatorBridge.swift`

```swift
public struct SimulatorBridge {
    public let udid: String

    public static func bootedDevice() -> SimulatorBridge?
    public static func device(udid: String) -> SimulatorBridge?

    public func screenshot(to path: String) throws -> Bool
    public func windowInfo() -> SimWindowInfo?
    public func iosPointToScreen(_ point: CGPoint) -> CGPoint
}

public struct SimWindowInfo {
    public let windowOrigin: CGPoint   // top-left of Simulator window content area
    public let contentSize: CGSize     // size of the iOS device screen area in macOS points
    public let deviceSize: CGSize      // iOS logical screen size (e.g. 393x852 for iPhone 15 Pro)
    public let scale: CGFloat          // contentSize.width / deviceSize.width
}
```

Implementation:
1. `bootedDevice()` — run `xcrun simctl list devices booted -j`, parse JSON, return first booted iOS device UDID
2. `device(udid:)` — validate UDID exists via `simctl list devices -j`
3. `screenshot(to:)` — run `xcrun simctl io <udid> screenshot <path>`, return success
4. `windowInfo()` — use AX to find Simulator window, compute content area (subtract toolbar), get device size from `simctl list devices -j`
5. `iosPointToScreen(_:)` — translate iOS logical point to macOS screen coordinates: `CGPoint(x: windowOrigin.x + point.x * scale, y: windowOrigin.y + point.y * scale)`

Shell-out helper: use `Process` to run simctl commands, capture stdout/stderr, parse JSON output.

### Track 2: Extend SessionStore for Simulator mode (P0)

Add to `SessionData`:
```swift
var simulatorUDID: String?       // non-nil when in simulator mode
var simulatorDeviceType: String? // e.g. "iPhone 17 Pro"
```

When `simulatorUDID` is set, commands know to use SimulatorBridge instead of pure AX.

### Track 3: Extend ConnectCommand (P0)

New flag: `--simulator [udid]`

```
agent-swift connect --simulator                    # auto-detect booted device
agent-swift connect --simulator 71B5ED46-...       # specific device
```

Implementation:
1. If `--simulator` with no value: call `SimulatorBridge.bootedDevice()`, error if none booted
2. If `--simulator <udid>`: call `SimulatorBridge.device(udid:)`, error if not found/not booted
3. Verify Simulator.app is running (check for `com.apple.iphonesimulator` process)
4. Store UDID + device type in session
5. Bring Simulator to front
6. JSON output: `{"connected": true, "mode": "simulator", "udid": "...", "deviceType": "iPhone 17 Pro"}`

Error cases:
- No simulator booted → exit 2, hint: "Boot a simulator first: xcrun simctl boot <udid>"
- Simulator.app not running → exit 2, hint: "Open Simulator.app or run: open -a Simulator"
- Invalid UDID → exit 2

### Track 4: Extend ScreenshotCommand for Simulator mode (P0)

When in simulator mode:
1. Use `SimulatorBridge.screenshot(to:)` instead of AX-based screencapture
2. Output path handling stays the same
3. JSON output includes `"mode": "simulator"` field

### Track 5: Extend ClickCommand for Simulator mode (P0)

When in simulator mode with coordinate args:
1. Interpret coordinates as iOS logical points (not macOS screen points)
2. Use `SimulatorBridge.iosPointToScreen()` to map to macOS coordinates
3. Call existing `AXClient.performClick(at:)` at the mapped coordinates
4. JSON output includes `"mode": "simulator"`, `"iosPoint": {x, y}`, `"screenPoint": {x, y}`

```
agent-swift click 196 400    # tap at iOS point (196, 400)
```

This is the critical path — a CGEvent click at the correct macOS coordinates on the Simulator window should translate to a touch event at the corresponding iOS position.

### Track 6: StatusCommand shows Simulator mode (P0)

When in simulator mode, status output includes:
```json
{"mode": "simulator", "udid": "71B5...", "deviceType": "iPhone 17 Pro"}
```

### Track 7: Tests (P0)

New file: `Tests/agent-swiftTests/SimulatorTests.swift`

Test SimulatorBridge parsing and coordinate mapping (no actual simulator required):

1. Parse simctl JSON device list — extract UDID and device type
2. Parse simctl JSON — handle empty/no booted devices
3. Coordinate mapping: iOS point (0,0) → window origin
4. Coordinate mapping: iOS point (393,852) → window bottom-right
5. Coordinate mapping with scale factor 0.5 (small window)
6. SessionData round-trip with simulatorUDID
7. SessionData round-trip without simulatorUDID (backwards compat)
8. SimWindowInfo scale calculation
9. Connect schema includes --simulator flag
10. Status output includes mode field

**Minimum: 10 new XCTAssert* calls.**

### Track 8: Bump Version to 0.3.0 (P0)

Major feature: simulator mode warrants minor version bump.

---

## Acceptance Criteria

1. `agent-swift connect --simulator` connects to a booted iOS Simulator
2. `agent-swift connect --simulator <udid>` connects to a specific Simulator
3. `agent-swift screenshot /tmp/sim.png` captures the iOS device screen (not macOS window)
4. `agent-swift click 196 400` taps at iOS logical point (196, 400) on the Simulator
5. `agent-swift status` shows simulator mode, UDID, and device type
6. `agent-swift disconnect` clears simulator session
7. All existing desktop-mode commands still work unchanged
8. `--json` flag produces structured JSON output for all simulator commands
9. Exit code 0 on success, 2 on error (same contract)
10. `swift build` succeeds
11. `swift test` succeeds with ≥ 78 tests (68 existing + 10 new)
12. Session file backwards compatible (old sessions without simulatorUDID still work)

---

## Build Loop Protocol

1. Add SimulatorBridge utility (Track 1)
2. Extend SessionStore (Track 2)
3. Extend ConnectCommand (Track 3)
4. Extend ScreenshotCommand (Track 4)
5. Extend ClickCommand (Track 5)
6. Extend StatusCommand (Track 6)
7. Add tests (Track 7)
8. Bump version (Track 8)
9. Run eval

---

## Rules

- **Existing tests are sacred**: do not weaken or delete passing tests.
- **Backwards compatibility is mandatory**: desktop mode must work exactly as before.
- **Session file format must be backwards compatible**: old sessions load without error.
- **No new external dependencies**: only `xcrun simctl` (ships with Xcode) and existing CGEvent.
- **macOS build required**: all changes must compile and test on macOS.
- **Coordinate mapping must be testable offline**: SimulatorBridge parsing and math must work without a running Simulator.
- **Shell-out commands must handle failures gracefully**: simctl not found, device not booted, etc.

## Prerequisites

- macOS with Xcode and Simulator installed
- AX trust granted to the agent-swift process (for CGEvent clicks and window position detection)
- A booted iOS Simulator for live testing
