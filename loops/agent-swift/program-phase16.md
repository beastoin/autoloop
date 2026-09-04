# Phase 16: Audit Remediation — Docs, Bugs, Cleanup

## Source
Independent Codex audit (2026-09-04), 5-turn adversarial debate. 10 findings, 4 HIGH / 4 MEDIUM / 2 LOW.

## Fixes

### HIGH
1. **README version + full rewrite** — Update from v0.2.1 to v0.10.0. Rewrite command table (18 commands), add all connect modes (--sim, --mirror, --udid), document record pipeline, frame processing, token optimization
2. **Prerequisites section** — Document all required tools: idb, xcrun simctl, ffmpeg, ffprobe, screencapture. Add version requirements
3. **`snapshot --all` no-op bug** — Either implement the flag for IdbBridge.describeAll() or remove the flag. Add test that verifies behavior, not constants
4. **PolishTests schema count** — Update test to expect current command count (18). Add assertion that schema count matches actual registered commands

### MEDIUM
5. **Simulator/mirror connect docs** — Document `--sim`, `--mirror`, `--udid` connect modes with examples. Add status JSON fields: mode, simulatorUDID, simulatorDeviceType
6. **`find` locator docs** — Document all supported locators: role, text, identifier, label, value, compound locators
7. **`record frame` ffmpeg guard** — Reorder guards so live-capture path (screencapture) doesn't require ffmpeg
8. **IDB path resolution** — Use resolved `which idb` path for execution, not hardcoded `/opt/homebrew/bin/idb`

### LOW
9. **WIDGET_SUPPORT.md counts** — Update role count, mapping count, display type count to match actual code
10. **Version constants in tests** — Update hardcoded version strings in UserUXTests, RecordingTests, FrameProcessingTests

## Acceptance Criteria
1. README version says 0.10.0
2. README command table has 18 entries
3. README documents --sim, --mirror, --udid connect modes
4. README has prerequisites section listing idb, ffmpeg, ffprobe, simctl, screencapture
5. `snapshot --all` either works for simulator or flag is removed
6. `find` docs show all 5+ locator types
7. IdbBridge execution uses resolved path, not hardcoded
8. All tests pass on Mac Mini (≥231 tests)
9. `swift build` succeeds
10. PolishTests schema count matches actual command count

## Target
- Version: 0.10.1 (patch — bugs + docs, no new features)
- Tests: ≥231
