# Phase 2b: Complete Widget Coverage for `agent-swift`

**Key Result: ROLE_MAP covers 100% of official macOS AX roles (64 from SDK headers), plus SwiftUI/runtime extras. Verified against System Settings.app.**

Build on the existing CLI in `loops/agent-swift/agent-swift` (all 5 phases complete, 59 tests).

## Before You Start

Read these files:
- `Sources/AgentSwiftLib/AX/AXClient.swift` — ROLE_MAP (66 entries), INTERACTIVE_ROLES (27 entries), displayType/isInteractive
- `Tests/agent-swiftTests/WidgetCoverageTests.swift` — existing coverage tests
- `WIDGET_SUPPORT.md` — current coverage matrix

### Official macOS AX roles (from AXRoleConstants.h + NSAccessibilityConstants.h):
The complete SDK role list (64 roles, excluding deprecated SortButton):
AXApplication, AXSystemWide, AXWindow, AXSheet, AXDrawer, AXGrowArea, AXImage, AXUnknown, AXButton, AXRadioButton, AXCheckBox, AXPopUpButton, AXMenuButton, AXTabGroup, AXTable, AXColumn, AXRow, AXOutline, AXBrowser, AXScrollArea, AXScrollBar, AXRadioGroup, AXList, AXGroup, AXValueIndicator, AXComboBox, AXSlider, AXIncrementor, AXBusyIndicator, AXProgressIndicator, AXRelevanceIndicator, AXToolbar, AXDisclosureTriangle, AXTextField, AXTextArea, AXStaticText, AXHeading, AXMenuBar, AXMenuBarItem, AXMenu, AXMenuItem, AXSplitGroup, AXSplitter, AXColorWell, AXTimeField, AXDateField, AXHelpTag, AXMatte, AXDockItem, AXRuler, AXRulerMarker, AXGrid, AXLevelIndicator, AXCell, AXLayoutArea, AXLayoutItem, AXHandle, AXPopover, AXLink, AXDateTimeArea, AXListMarker, AXPage, AXWebArea

### Study reference:
- The macOS SDK headers at: `$XCODE/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/Headers/AXRoleConstants.h`
- The AppKit header at: `$XCODE/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSAccessibilityConstants.h`

## Context

Phase 2 added 66 ROLE_MAP entries covering common controls, containers, menus, and content. But 6 official SDK roles are missing:
- `AXTimeField` — time input (scheduling UIs, Calendar.app, Clock.app)
- `AXDockItem` — Dock items
- `AXGrid` — grid/collection views (Photos, Launchpad)
- `AXPage` — page controls (document-based apps)
- `AXDateTimeArea` — combined date+time area
- `AXListMarker` — list bullet markers (macOS 26+)

This phase closes the gap to 100% official role coverage.

## Scope

### Track 1: Add Missing SDK Roles to ROLE_MAP (P0)

Add these 6 roles:

| AX Role | Display Type | Interactive? | Notes |
|---------|-------------|-------------|-------|
| `AXTimeField` | `timefield` | Yes | Time input control |
| `AXDockItem` | `dockitem` | Yes | Dock icon (pressable) |
| `AXGrid` | `grid` | No | Grid/collection container |
| `AXPage` | `page` | No | Page container |
| `AXDateTimeArea` | `datetimearea` | No | Combined date+time area |
| `AXListMarker` | `listmarker` | No | Bullet/number marker |

Add `AXTimeField` and `AXDockItem` to INTERACTIVE_ROLES.

### Track 2: Update WIDGET_SUPPORT.md (P0)

Update the coverage matrix to reflect all roles:
- Mark all 64 official SDK roles as covered
- List SwiftUI/runtime extras separately
- Show interactive vs non-interactive classification

### Track 3: Live Verification Against System Settings.app (P1)

Run `agent-swift snapshot -i` against System Settings.app (com.apple.systempreferences) and verify:
1. All visible controls get recognized types (not falling through to fallback)
2. Interactive controls are correctly classified
3. Snapshot format is clean

Also optionally test against Calendar.app (com.apple.iCal) for time/date field coverage.

### Track 4: Update Schema Command Count (P0)

Verify the schema command still lists 14 commands correctly (no change needed unless commands changed).

### Track 5: Test Coverage (P0)

Add tests to `WidgetCoverageTests.swift`:

1. All 6 new SDK roles are in ROLE_MAP
2. AXTimeField maps to "timefield"
3. AXDockItem maps to "dockitem"
4. AXGrid maps to "grid"
5. AXTimeField and AXDockItem are in INTERACTIVE_ROLES
6. AXPage, AXGrid, AXDateTimeArea, AXListMarker are NOT in INTERACTIVE_ROLES
7. Total ROLE_MAP count ≥ 72 (66 existing + 6 new)
8. Total SDK roles covered = 64 (complete coverage)

**Minimum: 10 new XCTAssert* calls.**

---

## Acceptance Criteria

1. ROLE_MAP contains all 64 official macOS AX roles from SDK headers.
2. AXTimeField maps to "timefield" and is interactive.
3. AXDockItem maps to "dockitem" and is interactive.
4. AXGrid maps to "grid" (container, not interactive).
5. AXPage maps to "page" (container, not interactive).
6. AXDateTimeArea maps to "datetimearea" (not interactive).
7. AXListMarker maps to "listmarker" (not interactive).
8. ROLE_MAP count ≥ 72.
9. INTERACTIVE_ROLES count ≥ 29 (27 existing + 2 new).
10. WIDGET_SUPPORT.md updated with complete coverage matrix.
11. `swift build` succeeds.
12. `swift test` succeeds with ≥ 69 tests (59 existing + 10 new).
13. All existing tests still pass.
14. `agent-swift snapshot -i --json` against System Settings.app returns valid JSON.
15. Eval phase_complete=yes.

---

## Build Loop Protocol

1. Add missing roles to ROLE_MAP and INTERACTIVE_ROLES (Track 1).
2. Update WIDGET_SUPPORT.md (Track 2).
3. Add tests (Track 5). Run eval.
4. Live verification against System Settings.app (Track 3).
5. Commit only when green.

---

## Rules

- **Existing tests are sacred**: do not weaken or delete passing tests.
- **Follow established patterns**: same ROLE_MAP dictionary format, same displayType style.
- **No regressions in snapshot format, exit codes, or --json output.**
- **Keep scope phase-local**: only widget coverage, no new commands.
- **macOS build required**: all changes must compile and test on macOS.
- **Use official Apple apps for E2E**: System Settings (com.apple.systempreferences) as primary target.
