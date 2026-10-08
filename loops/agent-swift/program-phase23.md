# Phase 23: Fix iOS Simulator connect hang and type bug

GitHub issue: https://github.com/beastoin/agent-swift/issues/3

## Environment
- macOS 26.6.2, Xcode 26.0.1, agent-swift 0.12.0
- Simulator: iPhone 17 Pro, iOS 26.0
- App under test: VoxBoard (com.thinhcto.Vox)

## R1: Connect timeout (Friction 1)

`connect --simulator <UDID>` and `connect --sim` hang indefinitely.

**Root cause**: `connectSimulator()` calls `idb.enableAccessibility()` which runs
`xcrun simctl spawn <udid> defaults write ...`. On iOS 26.0, `simctl spawn` hangs
indefinitely. `Process.waitUntilExit()` blocks forever. `try?` swallows errors but
not the blocking call.

**Fix**:
- Add `SimulatorBridge.runSimctlWithTimeout(_:timeout:)` that terminates the
  Process after a configurable timeout (default 10s)
- Change `enableAccessibility()` to use the timeout variant
- Return exit code 124 (matching `timeout(1)` convention) on timeout

**Acceptance**:
- `connect --simulator <UDID>` returns within 15s even when simctl spawn hangs
- If enableAccessibility times out, connect still succeeds (it's best-effort)

## R2: Fix type sending repeated 'a' (Friction 2)

`type 'hello from agent-swift'` sends "Aaaaaaaaaaaaaaaaaaaaaa" in Simulator.

**Root cause**: Both `typeViaCGEvent` implementations use `virtualKey: 0`
(= `kVK_ANSI_A`). While `keyboardSetUnicodeString` sets the correct character,
Simulator.app intercepts the hardware key code and maps it to the simulated
keyboard — so every character arrives as 'a'.

**Fix**:
- Add `SimulatorBridge.typeViaPasteboard(text:)` that uses:
  1. `xcrun simctl pbcopy <udid>` to set text on the simulator's pasteboard
  2. CGEvent Cmd+V to paste (virtualKey 9 = kVK_ANSI_V with .maskCommand)
- In `typeSimulator()`: replace CGEvent fallback with pasteboard method
- In `TypeCommand.run()` desktop path: detect Simulator (`bundleId ==
  "com.apple.iphonesimulator"`) and redirect to pasteboard approach
- Report `method: "pasteboard"` in JSON output

**Acceptance**:
- `type 'hello from agent-swift'` delivers the exact text to the iOS text field
- Works in both simulator mode and desktop-mode Simulator workaround
- JSON output includes `method: "pasteboard"` when pasteboard path is used

## R3: Version and tests

- Bump version to 0.13.0
- Add unit tests for timeout behavior and pasteboard detection logic
- All existing tests pass
- `swift build` succeeds

## Non-goals
- Not fixing idb compatibility with iOS 26 (upstream dependency)
- Not changing other simctl calls (only the spawn-based ones that hang)
