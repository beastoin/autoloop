# Phase 22: MenuBarExtra Automation, QA Diagnostics & Snapshot Filtering

## Context

GitHub issue #2: Manager used agent-swift for runtime QA of a SwiftUI MenuBarExtra app (tmv). Four friction points identified:

1. MenuBarExtra status items require AppleScript workaround to open — no native command
2. `doctor` doesn't diagnose TCC issues on the target app (only checks agent-swift itself)
3. Snapshot output includes all elements (closed menus, zero-bounds items) — no filtering
4. Collecting doctor + snapshot + screenshot for failure reports requires 4 separate commands

## Requirements

### R1: MenuBar Commands (`menubar list`, `menubar open`)

Create `menubar` subcommand group:

- `menubar list [--json]`:
  - List all menu bar items for the connected app's menu bars (AXMenuBar children)
  - For system-wide status items (MenuBarExtra), also walk SystemUIServer and the app's menu bar 2
  - Output: ref, title, role, enabled, subrole for each item
  - Schema entry with description, args, flags, exitCodes

- `menubar open <ref> [--json]`:
  - Perform AXPress on the referenced menu bar item to expand it
  - After press, re-walk and return the expanded menu items as a snapshot
  - If ref is a title string (not @eN), find by title match
  - Allows: `menubar open "tmv"` or `menubar open @e3`
  - Returns expanded menu items with refs for follow-up `press` calls

- System-wide access: use `AXUIElementCreateSystemWide()` to find status items across processes, filtered to the connected bundle's PID
- All output follows existing JSON envelope pattern

### R2: Target App TCC Diagnostics (`doctor --target-app`)

Extend `doctor` command:

- `doctor --target-app <path-or-bundle-id> [--json]`:
  - If connected, use the connected app. Otherwise, resolve by bundle ID or .app path
  - Run functional probes against the target:
    1. **AX tree probe**: Try `walkTree` on target PID → reports if AX access works
    2. **Screenshot probe**: Try `CGWindowListCreateImage` for target window → reports if screen capture works
    3. **Action probe**: Try AXPress on a known-safe element (if any interactive elements found in snapshot)
  - Check target app's code signing: `codesign --display --entitlements` → warn if unsigned or ad-hoc (identity changes on rebuild break TCC)
  - Report each probe as pass/warn/fail with remediation hint
  - JSON output: `{ "checks": [...], "target": { "bundleId": "...", "pid": N, "signed": true, "identity": "..." } }`

- Existing doctor checks unchanged (backward compatible)

### R3: Snapshot Filtering

Add filters to `snapshot` command:

- `--visible-only`: Exclude elements with nil position/size or fully off-screen bounds
- `--nonzero-bounds`: Exclude elements with width=0 or height=0
- `--role <role>`: Include only elements matching role (accepts AX role like "AXButton" or display type like "button")
- `--window-only`: Include only elements that are children of AXWindow nodes (exclude AXMenuBar and its descendants, AXApplication-level items)

Implementation:
- Apply filters after tree walk, before formatting
- Filters combine with AND logic (all must pass)
- Existing `-i` (interactive) filter remains and combines with new filters
- Schema updated with new flags

### R4: Collect Artifacts Command

Create `collect-artifacts` command:

- `collect-artifacts [--bundle-id <id>] [--out <dir>] [--json]`:
  - If not connected, connect to bundle-id first
  - Create output directory (default: `/tmp/agent-swift-artifacts-{timestamp}/`)
  - Collect and save:
    1. `doctor.json` — full doctor output including target probes
    2. `status.json` — session status
    3. `snapshot.json` — full snapshot (interactive mode)
    4. `screenshot.png` — current screenshot
  - Write `manifest.json` with: timestamp, version, bundleId, pid, file list with sizes
  - Return manifest in JSON output
  - If any collection step fails, record error in manifest but continue with remaining steps

### R5: Tests

- `MenuBarTests.swift`:
  - Test menubar list output format (JSON structure)
  - Test menubar open with ref and title
  - Test system-wide menu bar item discovery
  - ≥ 15 XCTAssert calls

- `QADiagnosticsTests.swift`:
  - Test doctor --target-app probe result structure
  - Test codesign parsing
  - Test functional probe result types (pass/warn/fail)
  - Test collect-artifacts manifest format
  - Test collect-artifacts with partial failures
  - ≥ 15 XCTAssert calls

- Existing snapshot filter tests:
  - Add filter tests to existing SnapshotTests or new SnapshotFilterTests.swift
  - Test --visible-only, --nonzero-bounds, --role, --window-only
  - Test filter combinations
  - ≥ 10 XCTAssert calls

### R6: Schema & Documentation

- `schema` output includes: menubar (with list/open subcommands), collect-artifacts
- `schema menubar` returns detailed command schema
- `schema collect-artifacts` returns detailed command schema
- Doctor schema updated with --target-app flag
- Snapshot schema updated with new filter flags
- AGENTS.md updated with new commands

## Acceptance Criteria

1. `swift build` succeeds
2. `swift test` passes (existing 290 + new ≥ 310 total)
3. `menubar list --json` returns valid JSON array of menu bar items
4. `menubar open @e1 --json` expands menu and returns menu items
5. `doctor --target-app com.apple.TextEdit --json` returns probe results
6. `snapshot --visible-only --json` filters zero-bounds elements
7. `snapshot --role AXButton --json` filters to buttons only
8. `collect-artifacts --out /tmp/test-artifacts --json` produces manifest with 4 files
9. All new commands in `schema` output
10. Version bumped to 0.12.0
11. All existing commands work unchanged (backward compatible)
12. All JSON output follows existing envelope pattern

## Non-Goals

- Cross-process menu item interaction (only connected app + its status items)
- TCC database direct query (too fragile, version-dependent)
- Video recording in artifacts (already has its own command)
- Automated TCC grant (requires user interaction)

## References

- GitHub issue: https://github.com/beastoin/agent-swift/issues/2
- Manager's tmv QA workflow: MenuBarExtra SwiftUI app with Accessibility + AI stub
- Existing AX role infrastructure: AXClient.swift ROLE_MAP, INTERACTIVE_ROLES
- Existing doctor structure: main.swift DoctorCommand
