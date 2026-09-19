# Phase 20: iOS 26 Simulator AX Fallback

## Problem

`idb ui describe-all` is broken on iOS 26.3 simulator ("No translation object returned for simulator"). This breaks `snapshot` and all element-based commands (find/press/fill/get/is/wait). `idb ui text` exits 0 but doesn't actually type on iOS 26.3. `doctor` doesn't detect these failures.

Reporter: finn (agent-swift v0.8.0, iPhone 17 sim, iOS 26.3, M4 Mac Mini)
GitHub Issue: beastoin/agent-swift#1

## Fix

When idb commands fail in simulator mode, fall back to macOS Accessibility APIs on the Simulator.app window. The Simulator app exposes the iOS accessibility tree through AXUIElement — same mechanism Xcode's Accessibility Inspector uses.

## Requirements

### 1. Snapshot AX Fallback
- When `idb ui describe-all` fails, fall back to AXUIElement tree walk on Simulator.app
- Find the Simulator window matching the connected UDID's device name
- Walk the AX tree and convert to AXNode format (same as desktop mode)
- Filter to interactive elements when `-i` flag is set
- Report which method was used in JSON output: `"method": "idb"` or `"method": "ax"`

### 2. Type AX/CGEvent Fallback
- When `idb ui text` fails, fall back to CGEvent keyboard typing through the Simulator window
- Activate Simulator.app window first (same as existing `tap`/`swipe` CGEvent path)
- Report method used: `"method": "idb"` or `"method": "cgevent"`

### 3. Doctor Functional Probe
- In simulator mode, doctor should try `idb ui describe-all` as a functional check
- Report "idb_accessibility" check with pass/warn status
- On failure: status "warn", message describes the fallback available
- Don't hard-fail doctor — the tool still works with AX fallback

### 4. Fill AX Fallback
- When `idb ui text` fails for fill command, fall back to AX-based fill
- Find the target element in the Simulator.app AX tree by coordinates
- Use AXSetValue to fill text

### 5. Tests
- SimAXFallbackTests.swift with >= 15 assertions
- Test: AX tree walk on Simulator.app produces valid elements
- Test: fallback triggers when idb fails
- Test: doctor reports idb_accessibility check
- Test: type fallback uses CGEvent
- Total test count must remain >= 248 (current)

## Acceptance Criteria

1. `swift build` succeeds
2. `swift test` passes (all existing + new tests)
3. `snapshot` works on iOS 26 simulator when idb fails (AX fallback)
4. `type` works on iOS 26 simulator when idb text fails (CGEvent fallback)
5. `doctor` reports idb_accessibility status for simulator mode
6. All existing commands continue to work (no regressions)
7. JSON output includes `method` field indicating which path was used
