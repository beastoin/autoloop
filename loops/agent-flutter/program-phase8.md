# agent-flutter Phase 8: Phrase Principle Alignment

## Problem

Phase 7 introduced `tap` as a separate command, violating the core UX
principle: `snapshot → @ref → press/fill/wait/is`. The `tap` command
duplicates `press` for ref-based taps and introduces raw pixel coordinates
outside the phrase vocabulary.

Design references (agent-device, agent-browser) all follow `@ref`-based
verb phrases. Raw coordinates are an escape hatch, not a separate verb.

## Changes

### 1. Merge `tap` into `press`

`press` becomes the single verb for all tap actions:

```bash
agent-flutter press @e3              # existing: Marionette ref tap
agent-flutter press 540 1200         # new: ADB coordinate tap (physical pixels)
agent-flutter press @e3 --adb        # new: ADB tap at ref center (bypasses Marionette)
```

Implementation:
- When args are two numbers: ADB coordinate tap (same as old `tap x y`)
- When arg is `@ref` without `--adb`: existing Marionette press (unchanged)
- When arg is `@ref` with `--adb`: compute center from bounds, ADB tap
  (same as old `tap @ref`)
- `--dry-run` works for all modes
- JSON output adds `method` field: `"marionette"`, `"coordinates"`, or `"adb-ref"`

### 2. Remove standalone `tap` command

- Remove `src/commands/tap.ts`
- Remove `tap` from CLI dispatch
- Remove `tap` from command-schema.ts
- Remove `tap` from help text

### 3. `dismiss` stays

`dismiss` is a system-level ADB command like `back` and `home`. It does
not operate on `@ref` elements. It stays as-is.

### 4. Update docs

- Update README.md command table (remove `tap`, update `press` description)
- Update AGENTS.md (remove `tap` from idempotency table, update `press`)
- Update help text in cli.ts

## Acceptance Criteria

- [ ] `agent-flutter press @e3` still works via Marionette (unchanged)
- [ ] `agent-flutter press 540 1200` taps via ADB at coordinates
- [ ] `agent-flutter press @e3 --adb` taps via ADB at ref center
- [ ] `agent-flutter tap` is gone (unknown command, exit 2)
- [ ] `tap` no longer appears in `agent-flutter schema`
- [ ] `press` schema updated with new args/flags
- [ ] `agent-flutter --help` shows `press` with coordinate support
- [ ] Existing tests pass (no regressions)
- [ ] JSON output includes `method` field for press
- [ ] `dismiss` command unchanged

## Non-goals

- Changing how `dismiss` works
- Adding coordinate support to other commands
- Changing Marionette protocol
