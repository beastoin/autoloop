# Phase 21: Background Input via SkyLight

## Context

CUA (trycua/cua, 23.5K★) achieves background input delivery on macOS using Apple's private SkyLight framework — synthetic mouse/keyboard events reach backgrounded apps without moving the real cursor or stealing focus. agent-swift currently uses `CGEvent.post(tap: .cgSessionEventTap)` everywhere, which is foreground-only: it warps the cursor, steals focus, and blocks multi-agent scenarios.

This phase adds SkyLight-based background input to agent-swift, enabling:
- Multiple agents automating different apps simultaneously
- Agent automation without interrupting the user's foreground work
- More reliable event delivery to specific windows (PID+WindowID targeting)

## Requirements

### R1: SkyLightBridge — Private API Loader

Create `Sources/AgentSwiftLib/Input/SkyLightBridge.swift`:

- Load `SkyLight.framework` via `dlopen`/`dlsym` at runtime (not link-time)
- Wrap these functions:
  - `SLEventPostToPid(pid, event)` — post event to specific PID
  - `CGEventSetWindowLocation(event, point)` — stamp window-local coordinates
  - `SLEventSetAuthenticationMessage(event)` — auth envelope for keyboard (Chromium/Electron trust on macOS 14+)
  - `SLEventSetIntegerValueField(event, field, value)` — set raw SkyLight fields
  - `CGSMainConnectionID()` — WindowServer connection
  - `SLSGetWindowOwner(connectionID, windowID)` — validate window ownership
- Fail gracefully: if dlsym returns nil for any function, that route is unavailable (not a fatal error)
- `isAvailable` property returns true only when all required symbols loaded
- Platform-gated: `#if canImport(AppKit)` (same as SimAXBridge)

### R2: CGEvent Field Stamping

Create `Sources/AgentSwiftLib/Input/EventStamping.swift`:

- Extension on CGEvent to stamp routing fields:
  - `.stampPID(_ pid: Int)` — set field 40 (target PID filter)
  - `.stampWindow(_ windowID: CGWindowID)` — set fields 51, 91, 92 (window routing)
  - `.setWindowLocation(_ point: CGPoint)` — wrapper for CGEventSetWindowLocation
- Primer mouseMoved: `EventStamping.primerMove(to: point, pid: pid, windowID: windowID)` — sends a mouseMoved before every click to prime AppKit's tracking state in backgrounded windows

### R3: Background Click

Add PID-targeted click to AXClient (or new BackgroundInput module):

- `clickBackground(at: CGPoint, pid: Int, windowID: CGWindowID)`:
  1. Send primer mouseMoved
  2. Create mouseDown with window-local coords + PID stamp + window stamp
  3. Post via SLEventPostToPid
  4. Wait 28ms (AppKit modal tracking minimum)
  5. Send mouseUp via same path
  6. Wait 40ms settle
- Falls back to current foreground click when SkyLight unavailable
- `scrollBackground(...)` — same pattern for scroll events
- Right-click and drag variants

### R4: Background Keyboard

Add PID-targeted keyboard delivery:

- `typeBackground(text: String, pid: Int)`:
  1. Create CGEventCreateKeyboardEvent with keycode 0 + Unicode string
  2. Attach auth envelope via SLEventSetAuthenticationMessage
  3. Stamp PID field (f40)
  4. Post via SLEventPostToPid
  5. 8ms between down/up transitions
- Modifier state management: explicitly clear modifier flags to prevent leakage from physical keyboard
- Falls back to current CGEvent keyboard when SkyLight unavailable

### R5: Focus Suppression

Create `Sources/AgentSwiftLib/Input/FocusGuard.swift`:

- `FocusGuard` class subscribing to `NSWorkspace.didActivateApplicationNotification`
- `withSuppression(for pid: Int, action: () throws -> T) rethrows -> T`:
  - Records current frontmost app before action
  - Executes action
  - If target app steals focus, immediately re-activates the prior frontmost app
- Deadline: 5-second maximum suppression (prevents leaked guards)
- Used automatically by background click/type operations
- Observer on background NSOperationQueue (not mainQueue)

### R6: Route Selection

Update `click`, `type`, and `scroll` commands:

- When `--background` flag is passed OR `AGENT_SWIFT_BACKGROUND=1`:
  - Use SkyLight PID-targeted delivery
  - Don't activate the target app
  - Don't move the cursor
- When `--foreground` or default (no flag):
  - Use current CGEvent.post(tap:) behavior (backward compatible)
- AX semantic actions (`press`, `fill` value writes) already work in background — no change needed
- Report delivery method in JSON output: `"delivery": "background"` or `"delivery": "foreground"`

### R7: Window ID Resolution

- During `connect`, resolve and store CGWindowID for the target app's main window
- Store in SessionData: `windowID: Int?`
- Resolution: walk CGWindowListCopyWindowInfo, match by ownerPID
- `snapshot` refreshes windowID on each call
- Commands that need background delivery use stored windowID

### R8: Tests

- Unit tests for SkyLightBridge.isAvailable (at least dlopen succeeds on macOS)
- Unit tests for EventStamping field values
- Unit tests for FocusGuard lifecycle (suppression lease, deadline)
- Unit tests for route selection logic
- SessionData.windowID persistence + backward compat
- Live validation: background click on TextEdit while another app is frontmost

## Acceptance Criteria

1. `swift build` succeeds (all new files compile)
2. `swift test` passes (existing 266 + new tests ≥ 280)
3. SkyLightBridge loads framework and resolves symbols on macOS 15+
4. `agent-swift click @e1 --background` clicks without moving cursor or stealing focus
5. `agent-swift type "hello" --background` types without activating the target app
6. FocusGuard prevents focus steal during AX actions with suppression
7. Backward compatible: all existing commands work unchanged without --background
8. JSON output includes delivery method

## Non-Goals

- True multi-pointer (macOS doesn't support it — CUA confirmed)
- Linux/X11 MPX support
- Browser/CDP integration
- Permission policy engine (overkill for our use case)
- Multi-touch synthesis in VMs

## References

- CUA Driver: github.com/trycua/cua (libs/cua-driver/)
- SkyLight APIs: platform-macos/src/input/skylight.rs
- Background input spec: docs/macos-background-input-v1-plan.md
- geni's deep research: http://100.125.36.102:10300/cua-deep-research-01m2vr5w61m0/
