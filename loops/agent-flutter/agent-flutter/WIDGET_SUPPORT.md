# Widget Support Matrix — agent-flutter

Complete coverage of official Flutter interactive widgets.

## Coverage Summary

| Category | Widgets | Display Types | Interactive |
|----------|---------|--------------|-------------|
| Material Buttons | 8 | button | Yes |
| Material Input | 4 | textfield, searchbar | Yes |
| Material Selection | 8 | switch, checkbox, radio, slider | Yes |
| Material Chips | 5 | chip | Yes |
| Material Dropdowns/Menus | 5 | dropdown, menu | Yes |
| Material Pickers | 2 | picker | Yes |
| Material Dialogs | 6 | dialog, banner, snackbar, tooltip | Partial |
| Material Navigation | 10 | appbar, navbar, drawer, tabbar, tab | Partial |
| Material Lists/Content | 6 | tile, card, table, stepper, panel | Partial |
| Material Gesture | 6 | gesture | Yes |
| Cupertino Interactive | 19 | (reuses Material display types) | Yes |
| Scrolling/Layout | 5 | list, grid, pageview, refresh | No |
| Display | 9 | label, image, icon, container, etc. | No |
| **Total** | **93** | **34 display types** | |

## Full Widget Table

### Material Buttons

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| ElevatedButton | button | Yes | Yes | |
| FilledButton | button | Yes | Yes | Includes .tonal variant |
| OutlinedButton | button | Yes | Yes | |
| TextButton | button | Yes | Yes | |
| IconButton | button | Yes | Yes | |
| FloatingActionButton | button | Yes | Yes | Includes .extended |
| SegmentedButton | button | Yes | Likely | M3 widget |
| MaterialButton | button | Yes | Yes | Base class |

### Material Text Input

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| TextField | textfield | Yes | Yes | |
| TextFormField | textfield | Yes | Yes | |
| SearchBar | searchbar | Yes | Unknown | M3 widget |
| SearchAnchor | searchbar | Yes | Unknown | M3 widget |

### Material Selection Controls

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| Switch | switch | Yes | Yes | |
| SwitchListTile | switch | Yes | Yes | |
| Checkbox | checkbox | Yes | Yes | |
| CheckboxListTile | checkbox | Yes | Yes | |
| Radio | radio | Yes | Yes | |
| RadioListTile | radio | Yes | Yes | |
| Slider | slider | Yes | Yes | Limited to tap (no drag) |
| RangeSlider | slider | Yes | Unknown | Two-thumb variant |

### Material Chips

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| Chip | chip | Yes | Unknown | Upstream gap likely |
| ActionChip | chip | Yes | Unknown | |
| ChoiceChip | chip | Yes | Unknown | |
| FilterChip | chip | Yes | Unknown | |
| InputChip | chip | Yes | Unknown | Deletable |

### Material Dropdowns & Menus

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| DropdownButton | dropdown | Yes | Yes | |
| DropdownButtonFormField | dropdown | Yes | Yes | |
| DropdownMenu | dropdown | Yes | Unknown | M3 widget |
| PopupMenuButton | menu | Yes | Yes | |
| MenuAnchor | menu | Yes | Unknown | M3 widget |

### Material Pickers

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| DatePickerDialog | picker | Yes | Unknown | Shown via showDatePicker() |
| TimePickerDialog | picker | Yes | Unknown | Shown via showTimePicker() |

### Material Dialogs & Feedback

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| AlertDialog | dialog | Yes | Unknown | Ephemeral — may not snapshot reliably |
| SimpleDialog | dialog | Yes | Unknown | |
| BottomSheet | dialog | Yes | Unknown | |
| MaterialBanner | banner | No | Unknown | |
| SnackBar | snackbar | Yes | Unknown | Short-lived |
| Tooltip | tooltip | No | Unknown | Long-press triggered |

### Material Navigation

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| AppBar | appbar | No | Yes | |
| SliverAppBar | appbar | No | Unknown | Scrollable variant |
| BottomAppBar | appbar | No | Unknown | |
| BottomNavigationBar | navbar | No | Yes | M2 |
| NavigationBar | navbar | No | Unknown | M3 replacement |
| NavigationRail | navbar | No | Unknown | Side rail |
| NavigationDrawer | drawer | No | Unknown | M3 |
| Drawer | drawer | No | Unknown | M2 |
| TabBar | tabbar | No | Yes | |
| Tab | tab | Yes | Yes | |

### Material Lists & Content

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| ListTile | tile | No | Yes | |
| ExpansionTile | tile | No | Unknown | Expandable |
| Card | card | No | Yes | |
| DataTable | table | No | Unknown | Sortable/selectable |
| Stepper | stepper | Yes | Unknown | |
| ExpansionPanelList | panel | No | Unknown | |

### Touch & Gesture

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| GestureDetector | gesture | Yes | Yes | |
| InkWell | gesture | Yes | Yes | |
| InkResponse | gesture | Yes | Yes | |
| Dismissible | gesture | Yes | Unknown | Swipe-to-dismiss |
| Draggable | gesture | Yes | Unknown | |
| LongPressDraggable | gesture | Yes | Unknown | |

### Cupertino Widgets

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| CupertinoButton | button | Yes | Unknown | |
| CupertinoTextField | textfield | Yes | Unknown | |
| CupertinoSearchTextField | searchbar | Yes | Unknown | |
| CupertinoTextFormFieldRow | textfield | Yes | Unknown | |
| CupertinoSwitch | switch | Yes | Unknown | |
| CupertinoSlider | slider | Yes | Unknown | |
| CupertinoCheckbox | checkbox | Yes | Unknown | |
| CupertinoRadio | radio | Yes | Unknown | |
| CupertinoSegmentedControl | segmented | Yes | Unknown | |
| CupertinoSlidingSegmentedControl | segmented | Yes | Unknown | |
| CupertinoPicker | picker | Yes | Unknown | Wheel picker |
| CupertinoDatePicker | picker | Yes | Unknown | |
| CupertinoTimerPicker | picker | Yes | Unknown | |
| CupertinoAlertDialog | dialog | Yes | Unknown | |
| CupertinoActionSheet | dialog | Yes | Unknown | |
| CupertinoContextMenu | menu | Yes | Unknown | 3D-touch |
| CupertinoNavigationBar | appbar | No | Unknown | |
| CupertinoTabBar | tabbar | No | Unknown | |
| CupertinoListTile | tile | No | Unknown | |

### Scrolling & Layout

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| ListView | list | No | No | Container, use scroll command |
| GridView | grid | No | No | Container, use scroll command |
| PageView | pageview | No | No | Container, use swipe command |
| ReorderableListView | list | No | No | Container |
| RefreshIndicator | refresh | No | No | Pull-to-refresh wrapper |

### Display (non-interactive)

| Flutter Widget | Display Type | Interactive | Marionette Detects | Notes |
|---------------|-------------|-------------|-------------------|-------|
| Text | label | No | Yes | |
| RichText | label | No | Yes | |
| Image | image | No | Yes | |
| Icon | icon | No | Yes | |
| Container | container | No | No | Layout |
| Column | column | No | No | Layout |
| Row | row | No | No | Layout |
| Stack | stack | No | No | Layout |
| Scaffold | scaffold | No | No | App structure |

## Marionette Detection Gaps

Widgets marked "Unknown" in the Marionette column have not been verified with a live Marionette-instrumented app. The TYPE_MAP entries exist for forward compatibility.

**Known undetectable by Marionette:**
- Layout containers (Container, Column, Row, Stack, Scaffold)
- Scroll containers (ListView, GridView, PageView)
- RefreshIndicator

**Workarounds for undetectable widgets:**
1. Wrap in `GestureDetector` with a `Key` for tap detection
2. Use `find text "label"` to locate by visible text (works even without Marionette detection)
3. Use `scroll`/`swipe` commands for scroll container interaction
4. For pickers/dialogs shown via `show*()` methods, use `wait` + `find` after they appear

## Interactive Types

These display types are included in `snapshot -i` (interactive filter):

```
button, textfield, searchbar, switch, checkbox, radio, slider,
chip, dropdown, menu, gesture, tab, segmented, picker, dialog,
stepper, snackbar
```

These are excluded from `snapshot -i`:

```
label, image, icon, container, column, row, stack, scaffold,
appbar, navbar, drawer, tabbar, tile, card, table, panel,
banner, tooltip, list, grid, pageview, refresh
```
