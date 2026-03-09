# Phase 2: Full macOS Widget Coverage for `agent-swift`

**Key Result: All official macOS accessibility roles supported, 100% tested.**

Build on the existing standalone CLI in `loops/agent-swift/agent-swift` (Phase 1 complete).

## Before You Start

Read these files:
- `Sources/AgentSwiftLib/AX/AXClient.swift` — current `displayType` switch (23 mappings), `isInteractive` set (19 roles), `collectElements()` duplicate interactive set
- `Tests/agent-swiftTests/AXNodeTests.swift` — existing type/interactive/label tests (5 tests)

## Context

Current `displayType` covers 23 AX roles via a switch statement. The macOS Accessibility API defines ~50 standard roles across controls, containers, content, and navigation categories. This phase closes the gap.

**Critical design change:** Replace the inline `switch` in `displayType` and the duplicated `Set<String>` in `isInteractive`/`collectElements()` with a centralized `ROLE_MAP` dictionary and `INTERACTIVE_ROLES` set — single source of truth, same pattern as agent-flutter's `TYPE_MAP`.

## Scope

### Track 1: Centralize Role Mapping (P0)

Replace the `displayType` switch statement with a static `ROLE_MAP: [String: String]` dictionary. Replace both duplicated `interactiveRoles` sets with a single static `INTERACTIVE_ROLES: Set<String>`.

### Track 2: ROLE_MAP Expansion (P0)

Add all standard macOS AX roles to `ROLE_MAP`. Organize by category.

#### Controls — Interactive (+5 new)
| AX Role | Display Type | Interactive |
|---------|-------------|-------------|
| `AXButton` | `button` | Yes |
| `AXTextField` | `textfield` | Yes |
| `AXTextArea` | `textfield` | Yes |
| `AXCheckBox` | `checkbox` | Yes |
| `AXRadioButton` | `radio` | Yes |
| `AXPopUpButton` | `dropdown` | Yes |
| `AXComboBox` | `dropdown` | Yes |
| `AXSlider` | `slider` | Yes |
| `AXSwitch` | `switch` | Yes |
| `AXToggle` | `switch` | Yes |
| `AXMenuItem` | `menuitem` | Yes |
| `AXMenuButton` | `menubutton` | Yes |
| `AXLink` | `link` | Yes |
| `AXTab` | `tab` | Yes |
| `AXTabGroup` | `tabgroup` | Yes |
| `AXDisclosureTriangle` | `disclosure` | Yes |
| `AXIncrementor` | `stepper` | Yes |
| `AXColorWell` | `colorwell` | Yes |
| `AXSegmentedControl` | `segmented` | Yes |
| `AXSearchField` | `searchfield` | Yes (NEW) |
| `AXDateField` | `datefield` | Yes (NEW) |
| `AXLevelIndicator` | `levelindicator` | Yes (NEW) |
| `AXRadioGroup` | `radiogroup` | Yes (NEW) |
| `AXStepper` | `stepper` | Yes (NEW) |

#### Navigation & Menus (+3 new)
| AX Role | Display Type | Interactive |
|---------|-------------|-------------|
| `AXMenu` | `menu` | No |
| `AXMenuBar` | `menubar` | No |
| `AXMenuBarItem` | `menubaritem` | Yes (NEW) |
| `AXMenuItemCheckbox` | `menuitem` | Yes (NEW) |
| `AXMenuItemRadio` | `menuitem` | Yes (NEW) |

#### Containers & Layout (+8 new)
| AX Role | Display Type | Interactive |
|---------|-------------|-------------|
| `AXGroup` | `group` | No |
| `AXWindow` | `window` | No |
| `AXToolbar` | `toolbar` | No |
| `AXScrollArea` | `scrollarea` | No |
| `AXTable` | `table` | No |
| `AXList` | `list` | No |
| `AXSplitGroup` | `splitgroup` | No (NEW) |
| `AXSplitter` | `splitter` | No (NEW) |
| `AXOutline` | `outline` | No (NEW) |
| `AXBrowser` | `browser` | No (NEW) |
| `AXSheet` | `sheet` | No (NEW) |
| `AXDrawer` | `drawer` | No (NEW) |
| `AXLayoutArea` | `layoutarea` | No (NEW) |
| `AXLayoutItem` | `layoutitem` | No (NEW) |

#### Table/List Structure (+3 new)
| AX Role | Display Type | Interactive |
|---------|-------------|-------------|
| `AXRow` | `row` | No (NEW) |
| `AXColumn` | `column` | No (NEW) |
| `AXCell` | `cell` | No (NEW) |

#### Content & Display (+6 new)
| AX Role | Display Type | Interactive |
|---------|-------------|-------------|
| `AXStaticText` | `label` | No |
| `AXImage` | `image` | No |
| `AXProgressIndicator` | `progressbar` | No (NEW) |
| `AXBusyIndicator` | `busyindicator` | No (NEW) |
| `AXValueIndicator` | `valueindicator` | No (NEW) |
| `AXRelevanceIndicator` | `relevanceindicator` | No (NEW) |
| `AXHeading` | `heading` | No (NEW) |
| `AXRuler` | `ruler` | No (NEW) |

#### Scroll Components (+2 new)
| AX Role | Display Type | Interactive |
|---------|-------------|-------------|
| `AXScrollBar` | `scrollbar` | No (NEW) |
| `AXHandle` | `handle` | No (NEW) |

#### System-Level (+3 new)
| AX Role | Display Type | Interactive |
|---------|-------------|-------------|
| `AXApplication` | `application` | No (NEW) |
| `AXSystemWide` | `system` | No (NEW) |
| `AXUnknown` | `unknown` | No (NEW) |

**Note on AXStaticText:** Rename from `statictext` to `label` for consistency with agent-flutter's Text → label convention.

**Total after expansion: ~55 role mappings → ~40 display types**

### Track 3: INTERACTIVE_ROLES Update (P0)

The centralized `INTERACTIVE_ROLES` set should contain all display types that appear in `snapshot -i`:

```
button, textfield, checkbox, radio, dropdown, slider, switch, menuitem,
menubutton, link, tab, tabgroup, disclosure, stepper, colorwell, segmented,
searchfield, datefield, levelindicator, radiogroup, menubaritem
```

Non-interactive (excluded from `-i`):
```
label, image, group, window, toolbar, scrollarea, table, list, menu, menubar,
splitgroup, splitter, outline, browser, sheet, drawer, layoutarea, layoutitem,
row, column, cell, progressbar, busyindicator, valueindicator, relevanceindicator,
heading, ruler, scrollbar, handle, application, system, unknown
```

### Track 4: Eliminate Duplication (P0)

The `collectElements()` method has its own copy of the interactive roles set. Refactor to use the same `INTERACTIVE_ROLES` set as `isInteractive`.

### Track 5: Test Coverage (P0)

Create `Tests/agent-swiftTests/WidgetCoverageTests.swift` with:

1. **ROLE_MAP completeness test**: Every standard AX role maps to a known display type.
2. **Display type consistency test**: All ROLE_MAP values are from a known set.
3. **Interactive classification test**: For each interactive role, verify `isInteractive == true`. For non-interactive, verify `isInteractive == false`.
4. **Category grouping tests**: Controls, containers, content, navigation — test each group.
5. **Fallback behavior test**: Unknown roles strip "AX" prefix and lowercase.
6. **Snapshot line format test**: Verify `@eN [type] "label"` for new display types.
7. **AXStaticText → label rename test**: Verify `AXStaticText` now maps to `label` not `statictext`.

**Minimum: 50 XCTAssert* calls across all tests.**

### Track 6: Documentation (P1)

Create `WIDGET_SUPPORT.md` documenting:
- Full role coverage table (AX role → display type → interactive?)
- Known gaps/limitations
- Subrole handling notes (stored but not used for classification)

---

## Acceptance Criteria

1. `ROLE_MAP` dictionary exists as a static `[String: String]` (not a switch).
2. `INTERACTIVE_ROLES` exists as a single static `Set<String>`.
3. No duplicate interactive role definitions (collectElements uses same set).
4. `ROLE_MAP` contains ≥ 50 entries.
5. All 8 button/control variants map correctly (Button, TextField, etc.).
6. All 5 chip/dropdown variants map correctly.
7. `AXSearchField` maps to `searchfield` and is interactive.
8. `AXStaticText` maps to `label` (not `statictext`).
9. `AXProgressIndicator` maps to `progressbar`.
10. `AXOutline` maps to `outline`.
11. `AXSheet` maps to `sheet`.
12. `AXSplitGroup` maps to `splitgroup`.
13. `AXRow`, `AXColumn`, `AXCell` are mapped.
14. `AXApplication` maps to `application`.
15. `INTERACTIVE_ROLES` includes `searchfield`, `datefield`, `menubaritem`.
16. `isInteractive` returns true for `AXSearchField`.
17. `isInteractive` returns false for `AXProgressIndicator`, `AXOutline`, `AXSheet`.
18. Fallback: `AXCustomThing` → `customthing`.
19. `WidgetCoverageTests.swift` exists.
20. ≥ 50 XCTAssert* calls in widget coverage tests.
21. All tests pass (`swift test`).
22. Build succeeds (`swift build`).
23. `WIDGET_SUPPORT.md` exists.
24. Existing tests remain passing.
25. No regressions in snapshot format (`@eN [type] "label"`).
26. No regressions in exit codes (0/1/2).
27. Snapshot JSON output preserves `role` field (raw AX role).

---

## Build Loop Protocol

1. Refactor displayType switch → ROLE_MAP dictionary + INTERACTIVE_ROLES set.
2. Run eval after refactor. Must not regress existing tests.
3. Add new role mappings in groups (controls, containers, content, etc.).
4. Add corresponding tests after each group.
5. Run `swift build && swift test` after each group.
6. Run eval after each group.
7. Create WIDGET_SUPPORT.md.
8. Run eval — all gates green.
9. Commit only when green.

---

## Rules

- **Existing tests are sacred**: do not weaken or delete passing tests.
- **No new command behavior**: this phase is ROLE_MAP + tests + docs only.
- **No regressions in snapshot format or exit codes.**
- **Single source of truth**: ROLE_MAP is the canonical role mapping, INTERACTIVE_ROLES is the canonical interactive set.
- **Forward compatibility**: map roles even if rarely encountered — the ROLE_MAP should handle any standard AX role.
