# Phase 6: Full Flutter Widget Coverage for `agent-flutter`

**Key Result: All official Flutter interactive widgets supported, 100% tested.**

Build on the existing standalone CLI in `loops/agent-flutter/agent-flutter` (Phases 1–5 complete).

## Before You Start

Read these files:
- `src/snapshot-fmt.ts` — current `TYPE_MAP` (32 widget types → 19 display types), `INTERACTIVE_TYPES`, `normalizeType()`
- `__tests__/snapshot-fmt.test.ts` — existing type mapping tests
- `__tests__/snapshot-filter.test.ts` — interactive filter tests

## Context

Current `TYPE_MAP` covers 32 Flutter widget types. The official Flutter widget catalog has ~111 interactive widget types across Material, Cupertino, scrolling, and gesture categories. This phase closes the gap.

**Critical constraint:** agent-flutter depends on Marionette's `interactiveElements()` RPC. The TYPE_MAP is a display-name mapping — Marionette must detect the widget for it to appear in snapshots. This phase covers what agent-flutter can control on its side (recognition + classification). Widgets Marionette cannot detect are documented as "upstream gap" but still get TYPE_MAP entries for forward compatibility.

## Scope

### Track 1: TYPE_MAP Expansion (P0)

Add all official Flutter interactive widgets to `TYPE_MAP` in `src/snapshot-fmt.ts`. Organize by category.

#### Material Buttons (+4)
| Widget | Display Type |
|--------|-------------|
| `SegmentedButton` | `button` |
| `InkResponse` | `gesture` |
| `MaterialButton` | `button` |
| `FilledButton.tonal` | `button` |

Note: `FilledButton.tonal` may appear as `FilledButton` in the element tree. Keep `FilledButton` → `button` mapping; no separate entry needed if Marionette doesn't distinguish the variant.

#### Material Input (+2)
| Widget | Display Type |
|--------|-------------|
| `SearchBar` | `searchbar` |
| `SearchAnchor` | `searchbar` |

#### Material Selection (+1)
| Widget | Display Type |
|--------|-------------|
| `RangeSlider` | `slider` |

#### Material Chips (+5) — new display type `chip`
| Widget | Display Type |
|--------|-------------|
| `Chip` | `chip` |
| `ActionChip` | `chip` |
| `ChoiceChip` | `chip` |
| `FilterChip` | `chip` |
| `InputChip` | `chip` |

#### Material Dropdowns/Menus (+3)
| Widget | Display Type |
|--------|-------------|
| `DropdownButtonFormField` | `dropdown` |
| `DropdownMenu` | `dropdown` |
| `MenuAnchor` | `menu` |

#### Material Pickers (+2) — new display type `picker`
| Widget | Display Type |
|--------|-------------|
| `DatePickerDialog` | `picker` |
| `TimePickerDialog` | `picker` |

#### Material Dialogs/Sheets (+4) — new display type `dialog`
| Widget | Display Type |
|--------|-------------|
| `AlertDialog` | `dialog` |
| `SimpleDialog` | `dialog` |
| `BottomSheet` | `dialog` |
| `MaterialBanner` | `banner` |

#### Material Navigation (+6)
| Widget | Display Type |
|--------|-------------|
| `NavigationBar` | `navbar` |
| `NavigationRail` | `navbar` |
| `NavigationDrawer` | `drawer` |
| `Drawer` | `drawer` |
| `SliverAppBar` | `appbar` |
| `BottomAppBar` | `appbar` |

#### Material Lists/Content (+4)
| Widget | Display Type |
|--------|-------------|
| `ExpansionTile` | `tile` |
| `DataTable` | `table` |
| `Stepper` | `stepper` |
| `ExpansionPanelList` | `panel` |

#### Material Feedback (+2)
| Widget | Display Type |
|--------|-------------|
| `SnackBar` | `snackbar` |
| `Tooltip` | `tooltip` |

#### Cupertino Widgets (+18)
| Widget | Display Type |
|--------|-------------|
| `CupertinoButton` | `button` |
| `CupertinoSwitch` | `switch` |
| `CupertinoSlider` | `slider` |
| `CupertinoCheckbox` | `checkbox` |
| `CupertinoRadio` | `radio` |
| `CupertinoTextField` | `textfield` |
| `CupertinoSearchTextField` | `searchbar` |
| `CupertinoTextFormFieldRow` | `textfield` |
| `CupertinoSegmentedControl` | `segmented` |
| `CupertinoSlidingSegmentedControl` | `segmented` |
| `CupertinoPicker` | `picker` |
| `CupertinoDatePicker` | `picker` |
| `CupertinoTimerPicker` | `picker` |
| `CupertinoAlertDialog` | `dialog` |
| `CupertinoActionSheet` | `dialog` |
| `CupertinoContextMenu` | `menu` |
| `CupertinoNavigationBar` | `appbar` |
| `CupertinoTabBar` | `tabbar` |
| `CupertinoListTile` | `tile` |

#### Scrolling/Layout (+5)
| Widget | Display Type |
|--------|-------------|
| `ListView` | `list` |
| `GridView` | `grid` |
| `PageView` | `pageview` |
| `ReorderableListView` | `list` |
| `RefreshIndicator` | `refresh` |

#### Gesture/Interaction (+3)
| Widget | Display Type |
|--------|-------------|
| `Dismissible` | `gesture` |
| `Draggable` | `gesture` |
| `LongPressDraggable` | `gesture` |

**Total new mappings: ~59 widget types**
**Total after expansion: ~91 widget types → ~30 display types**

### Track 2: INTERACTIVE_TYPES Update (P0)

Add new interactive display types to `INTERACTIVE_TYPES`:

```
chip, searchbar, segmented, picker, dialog, stepper, snackbar
```

These are user-interactive and should appear in `snapshot -i` output.

Non-interactive display types (layout/container, excluded from -i):
```
drawer, banner, tooltip, table, panel, list, grid, pageview, refresh
```

### Track 3: Test Coverage (P0)

Create `__tests__/widget-coverage.test.ts` with:

1. **TYPE_MAP completeness test**: Verify every widget in the official catalog is mapped. Use a hardcoded `EXPECTED_WIDGETS` array covering all ~91 types. Test that `normalizeType()` returns a known display type for each.

2. **Display type consistency test**: Every TYPE_MAP value must be a known display type from a `KNOWN_DISPLAY_TYPES` set.

3. **Interactive classification test**: For each new interactive widget type, verify `filterInteractive()` includes it. For each non-interactive type, verify exclusion.

4. **Category grouping tests**: Group widgets by category (Material Buttons, Cupertino, Chips, etc.) and test each group maps to the expected display type.

5. **Fallback behavior test**: Unknown widget types should lowercase to `fluttertype → fluttertype.toLowerCase()`.

6. **Snapshot line format test**: For each new display type (`chip`, `searchbar`, `segmented`, `picker`, `dialog`, `stepper`, `snackbar`), verify `formatSnapshotLine()` produces correct `@eN [type] "label"` output.

7. **JSON format test**: Verify `formatSnapshotJson()` includes `flutterType` alongside normalized `type` for all new widgets.

**Minimum test count: 50 new tests** (covering all ~59 new widget types + display types + classification + formatting).

### Track 4: Documentation (P1)

Update `AGENTS.md` to include:
- Complete widget type table (all ~91 types grouped by category)
- Which display types are interactive vs display-only
- Cupertino widget support section
- Note on Marionette detection limitations

### Track 5: Marionette Gap Documentation (P1)

Create `WIDGET_SUPPORT.md` in the agent-flutter package root documenting:
- Full widget coverage table (widget → display type → interactive? → Marionette detects?)
- Known gaps where Marionette cannot detect certain widgets
- Workarounds (e.g., wrapping in GestureDetector for undetectable widgets)

---

## Acceptance Criteria

1. `TYPE_MAP` in `snapshot-fmt.ts` contains ≥ 85 entries.
2. All 6 Material button variants are mapped to `button`.
3. All 5 Material chip variants are mapped to `chip`.
4. All 3 Cupertino input widgets are mapped (`textfield`/`searchbar`).
5. All 3 Cupertino picker widgets are mapped to `picker`.
6. All 3 Cupertino dialog/action widgets are mapped to `dialog`/`menu`.
7. `CupertinoButton` maps to `button`.
8. `CupertinoSwitch` maps to `switch`.
9. `CupertinoNavigationBar` maps to `appbar`.
10. `CupertinoTabBar` maps to `tabbar`.
11. `NavigationBar` (M3) maps to `navbar`.
12. `NavigationRail` maps to `navbar`.
13. `NavigationDrawer` maps to `drawer`.
14. `SearchBar` maps to `searchbar`.
15. `SegmentedButton` maps to `button`.
16. `INTERACTIVE_TYPES` includes `chip`, `searchbar`, `segmented`, `picker`, `dialog`, `stepper`, `snackbar`.
17. `filterInteractive()` passes chips, pickers, segmented controls, dialogs.
18. `filterInteractive()` excludes drawers, tooltips, tables, lists, grids.
19. `__tests__/widget-coverage.test.ts` exists.
20. Widget coverage tests have ≥ 50 assertions.
21. All new widget types have a `normalizeType()` test.
22. All new display types have a `formatSnapshotLine()` test.
23. Existing tests remain passing.
24. `npx tsc --noEmit` passes.
25. `AGENTS.md` includes complete widget type table.
26. `WIDGET_SUPPORT.md` exists with coverage matrix.
27. No regressions in snapshot format (`@eN [type] "label"`).
28. No regressions in exit code contract (0/1/2).
29. `normalizeType('UnknownWidget')` returns `'unknownwidget'` (fallback preserved).
30. JSON snapshot output includes `flutterType` for all new widget types.

---

## Build Loop Protocol

1. Add new TYPE_MAP entries in logical groups (buttons, chips, cupertino, etc.).
2. Add corresponding tests after each group.
3. Run `npx tsc --noEmit` after each group.
4. Run `node --test __tests__/widget-coverage.test.ts` after each group.
5. Run full test suite before commit.
6. Update AGENTS.md and WIDGET_SUPPORT.md last.
7. Commit only when green.

---

## Rules

- **Existing tests are sacred**: do not weaken or delete passing tests.
- **No speculative interaction changes**: this phase is TYPE_MAP + tests + docs only. No new command behavior.
- **No regressions in snapshot format or exit codes**.
- **Forward compatibility**: map widgets even if Marionette can't detect them yet — the TYPE_MAP should be ready when Marionette adds support.
- **Single source of truth**: `TYPE_MAP` in `snapshot-fmt.ts` is the canonical widget mapping.
