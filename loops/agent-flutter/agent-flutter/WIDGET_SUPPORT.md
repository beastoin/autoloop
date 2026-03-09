# Widget Support Matrix

Coverage of Flutter widget types in agent-flutter's `TYPE_MAP` (source: `src/snapshot-fmt.ts`).

## Coverage Summary

- **Total widget mappings:** 93
- **Display types:** ~30
- **Interactive types (appear in `snapshot -i`):** 17

## Material Buttons

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `ElevatedButton` | `button` | Yes | Yes |
| `FilledButton` | `button` | Yes | Yes |
| `OutlinedButton` | `button` | Yes | Yes |
| `TextButton` | `button` | Yes | Yes |
| `IconButton` | `button` | Yes | Yes |
| `FloatingActionButton` | `button` | Yes | Yes |
| `SegmentedButton` | `button` | Yes | Yes |
| `MaterialButton` | `button` | Yes | Yes |

Note: `FilledButton.tonal` appears as `FilledButton` in the element tree. No separate entry needed.

## Material Text Input

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `TextField` | `textfield` | Yes | Yes |
| `TextFormField` | `textfield` | Yes | Yes |
| `SearchBar` | `searchbar` | Yes | Yes |
| `SearchAnchor` | `searchbar` | Yes | Yes |

## Material Selection Controls

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `Switch` | `switch` | Yes | Yes |
| `SwitchListTile` | `switch` | Yes | Yes |
| `Checkbox` | `checkbox` | Yes | Yes |
| `CheckboxListTile` | `checkbox` | Yes | Yes |
| `Radio` | `radio` | Yes | Yes |
| `RadioListTile` | `radio` | Yes | Yes |
| `Slider` | `slider` | Yes | Yes |
| `RangeSlider` | `slider` | Yes | Yes |

## Material Chips

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `Chip` | `chip` | Yes | Yes |
| `ActionChip` | `chip` | Yes | Yes |
| `ChoiceChip` | `chip` | Yes | Yes |
| `FilterChip` | `chip` | Yes | Yes |
| `InputChip` | `chip` | Yes | Yes |

## Material Dropdowns & Menus

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `DropdownButton` | `dropdown` | Yes | Yes |
| `DropdownButtonFormField` | `dropdown` | Yes | Yes |
| `DropdownMenu` | `dropdown` | Yes | Yes |
| `PopupMenuButton` | `menu` | Yes | Yes |
| `MenuAnchor` | `menu` | Yes | Yes |

## Material Pickers

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `DatePickerDialog` | `picker` | Yes | Partial — depends on dialog visibility |
| `TimePickerDialog` | `picker` | Yes | Partial — depends on dialog visibility |

## Material Dialogs & Feedback

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `AlertDialog` | `dialog` | Yes | Partial — overlay widgets |
| `SimpleDialog` | `dialog` | Yes | Partial — overlay widgets |
| `BottomSheet` | `dialog` | Yes | Partial — overlay widgets |
| `MaterialBanner` | `banner` | No | Yes |
| `SnackBar` | `snackbar` | Yes | Partial — transient |
| `Tooltip` | `tooltip` | No | Partial — hover-triggered |

## Material Navigation

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `AppBar` | `appbar` | No | Yes |
| `SliverAppBar` | `appbar` | No | Yes |
| `BottomAppBar` | `appbar` | No | Yes |
| `BottomNavigationBar` | `navbar` | No | Yes |
| `NavigationBar` | `navbar` | No | Yes |
| `NavigationRail` | `navbar` | No | Yes |
| `NavigationDrawer` | `drawer` | No | Yes |
| `Drawer` | `drawer` | No | Yes |
| `TabBar` | `tabbar` | No | Yes |
| `Tab` | `tab` | Yes | Yes |

## Material Lists & Content

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `ListTile` | `tile` | No | Yes |
| `ExpansionTile` | `tile` | No | Yes |
| `Card` | `card` | No | Yes |
| `DataTable` | `table` | No | Yes |
| `Stepper` | `stepper` | Yes | Yes |
| `ExpansionPanelList` | `panel` | No | Yes |

## Material Touch & Gesture

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `GestureDetector` | `gesture` | Yes | Yes |
| `InkWell` | `gesture` | Yes | Yes |
| `InkResponse` | `gesture` | Yes | Yes |
| `Dismissible` | `gesture` | Yes | Yes |
| `Draggable` | `gesture` | Yes | Yes |
| `LongPressDraggable` | `gesture` | Yes | Yes |

## Cupertino Buttons & Input

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `CupertinoButton` | `button` | Yes | Yes |
| `CupertinoTextField` | `textfield` | Yes | Yes |
| `CupertinoSearchTextField` | `searchbar` | Yes | Yes |
| `CupertinoTextFormFieldRow` | `textfield` | Yes | Yes |

## Cupertino Selection Controls

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `CupertinoSwitch` | `switch` | Yes | Yes |
| `CupertinoSlider` | `slider` | Yes | Yes |
| `CupertinoCheckbox` | `checkbox` | Yes | Yes |
| `CupertinoRadio` | `radio` | Yes | Yes |
| `CupertinoSegmentedControl` | `segmented` | Yes | Yes |
| `CupertinoSlidingSegmentedControl` | `segmented` | Yes | Yes |

## Cupertino Pickers & Dialogs

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `CupertinoPicker` | `picker` | Yes | Yes |
| `CupertinoDatePicker` | `picker` | Yes | Yes |
| `CupertinoTimerPicker` | `picker` | Yes | Yes |
| `CupertinoAlertDialog` | `dialog` | Yes | Partial — overlay |
| `CupertinoActionSheet` | `dialog` | Yes | Partial — overlay |
| `CupertinoContextMenu` | `menu` | Yes | Partial — overlay |

## Cupertino Navigation

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `CupertinoNavigationBar` | `appbar` | No | Yes |
| `CupertinoTabBar` | `tabbar` | No | Yes |
| `CupertinoListTile` | `tile` | No | Yes |

## Scrolling & Layout

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `ListView` | `list` | No | Yes |
| `GridView` | `grid` | No | Yes |
| `PageView` | `pageview` | No | Yes |
| `ReorderableListView` | `list` | No | Yes |
| `RefreshIndicator` | `refresh` | No | Yes |

## Display (Non-Interactive)

| Widget | Display Type | Interactive | Marionette Detects |
|--------|-------------|-------------|-------------------|
| `Text` | `label` | No | Yes |
| `RichText` | `label` | No | Yes |
| `Image` | `image` | No | Yes |
| `Icon` | `icon` | No | Yes |
| `Container` | `container` | No | Yes |
| `Column` | `column` | No | Yes |
| `Row` | `row` | No | Yes |
| `Stack` | `stack` | No | Yes |
| `Scaffold` | `scaffold` | No | Yes |

## Interactive vs Non-Interactive Classification

**Interactive** (included in `snapshot -i`):
`button`, `textfield`, `switch`, `checkbox`, `radio`, `slider`, `dropdown`, `menu`, `gesture`, `tab`, `chip`, `searchbar`, `segmented`, `picker`, `dialog`, `stepper`, `snackbar`

**Non-interactive** (excluded from `snapshot -i`):
`appbar`, `navbar`, `drawer`, `tabbar`, `tile`, `card`, `table`, `panel`, `banner`, `tooltip`, `list`, `grid`, `pageview`, `refresh`, `label`, `image`, `icon`, `container`, `column`, `row`, `stack`, `scaffold`

## Known Marionette Detection Gaps

Marionette's `interactiveElements()` RPC may not detect:

1. **Overlay widgets** (dialogs, sheets, action sheets) — only visible when actively shown. Marionette may not traverse overlay routes.
2. **Transient widgets** (SnackBar, Tooltip) — appear briefly and may not be captured during snapshot timing.
3. **Picker dialogs** (DatePickerDialog, TimePickerDialog) — similar to overlays, detection depends on dialog state.

### Workarounds

- **For undetectable widgets:** Wrap in a `GestureDetector` with a `Key` so Marionette can detect the wrapper.
- **For overlay/dialog widgets:** Take snapshot while the dialog is visible (after `press` that opens it).
- **For transient widgets:** Use `wait` command to synchronize with their appearance, then snapshot immediately.

## Fallback Behavior

Unknown widget types not in `TYPE_MAP` are lowercased: `MyCustomWidget` → `mycustomwidget`. This ensures forward compatibility — new Flutter widgets work immediately with a degraded but functional display type.
