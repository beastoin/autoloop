# Phase 13: Safe Back + Keyboard Dismiss + Element Labels

## Source
E2E test findings (2026-09-04) + kanban items from sora feedback.

## Problem
1. **`back` after `fill` sends app to home**: On Android, `back` first dismisses the keyboard, then a second `back` sends the app to the home screen. Agents calling `back` after `fill` unknowingly exit the app.
2. **Element labels in snapshot are sparse**: Many Flutter elements in snapshot output lack meaningful labels, making it harder for agents to identify targets. Labels from semantics properties (tooltip, label, hint) should be surfaced.
3. **Keyboard state detection**: No way to check if the keyboard is showing, so agents can't know whether `back` will dismiss keyboard or navigate.

## Acceptance Criteria

### AC1: `dismiss-keyboard` command
- New command `dismiss-keyboard` that reliably hides the soft keyboard on Android
- Uses `adb shell input keyevent KEYCODE_ESCAPE` or `adb shell input keyevent 111` (escape key) which dismisses keyboard without navigating
- Returns success/no-op result in JSON mode
- Schema entry present

### AC2: `back` warns when keyboard is visible
- `back` command detects if keyboard is showing (via `adb shell dumpsys input_method | grep mInputShown`)
- When keyboard is visible, `back` first dismisses keyboard and warns: "Keyboard dismissed. Run back again to navigate."
- When keyboard is not visible, `back` navigates as before
- JSON output includes `keyboardDismissed: true/false` field

### AC3: Improved element labels in snapshot
- Snapshot output includes `tooltip`, `hint`, and `semanticLabel` from Flutter semantics tree when available
- These appear as `label` in the snapshot ref table, with fallback priority: tooltip > semanticLabel > hint > type
- At least 3 new test assertions verifying label extraction

### AC4: Unit tests
- Test for dismiss-keyboard command parsing
- Test for keyboard detection logic
- Test for label extraction from semantics data
- At least 8 new test assertions total

## Implementation Notes
- `back` is in `src/commands/back.ts` — add keyboard check before sending back key
- Keyboard detection: `adb shell dumpsys input_method | grep mInputShown=true`
- Dismiss: `adb shell input keyevent 111` (KEYCODE_ESCAPE) — dismisses keyboard without navigating
- Snapshot label enrichment is in `src/snapshot.ts` or `src/commands/snapshot.ts`
- Flutter VM Service returns semantics properties via `getObject` on RenderObject/SemanticsNode

## Out of Scope
- iOS keyboard handling (agent-flutter is Android-only currently)
- Custom keyboard detection for third-party keyboards
- Refactoring snapshot format (keep backward compatible)
