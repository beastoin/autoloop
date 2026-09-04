# Phase 12: Fix `find text` URI Bug + Test Hardening

## Source
E2E test suite development (2026-09-04). `find text` uses auto-detected WebSocket URI instead of session URI, causing connection failures and VM deadlock.

## Problem
1. **`find text` wrong URI**: The `find text` command auto-detects a development-service WebSocket URI instead of using the stored session URI. This causes `WebSocket connection failed` errors and can deadlock the Dart VM service for subsequent commands.
2. **`find key` may also have the issue**: Needs investigation — `find key` worked in some runs but not others.
3. **Missing unit tests**: The `find` command has no unit tests for its network behavior.

## Acceptance Criteria

### AC1: `find text` uses session URI
- `connect → snapshot → find text <visible_text>` returns the matching element
- `find text` must use the VM service URI from the session file, not auto-detect
- No `WebSocket connection failed` errors when session is active

### AC2: `find key` uses session URI
- Same fix applied to `find key` if it has the same auto-detection path
- Both `find key` and `find text` work reliably after `fill` + keyboard dismiss

### AC3: Unit tests for find command
- Test: `find key <key>` returns matching element from snapshot
- Test: `find text <text>` returns matching element from snapshot
- Test: `find` with no match returns proper NOT_FOUND error
- Test: `find` with chained action (press/fill/get) works

### AC4: E2E find text test passes
- The E2E test suite at `shared/e2e-flutter-app/e2e/e2e-full.sh` should include and pass a `find text` test

## Implementation Notes
- `find` command is in `src/commands/find.ts`
- It calls through `vm-client.ts` which should use the session's `vmServiceUri`
- The bug may be in `auto-detect.ts` being called during find instead of using session state
- Check if `find` creates a new VmClient instead of reusing the session's client

## Out of Scope
- Adding new find locator types
- Changing find's chained action behavior
