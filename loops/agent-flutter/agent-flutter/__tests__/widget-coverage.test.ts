import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeType, filterInteractive, formatSnapshotLine } from '../src/snapshot-fmt.ts';
import type { FlutterElement } from '../src/vm-client.ts';

function mkEl(type: string, text?: string): FlutterElement & { ref: string } {
  return { type, text, key: undefined, visible: true, bounds: { x: 0, y: 0, width: 100, height: 48 }, ref: 'e1' };
}

// ─── Material Buttons (8 assertions) ────────────────────────────────
describe('Material Buttons', () => {
  it('maps all button variants', () => {
    assert.equal(normalizeType('ElevatedButton'), 'button');
    assert.equal(normalizeType('FilledButton'), 'button');
    assert.equal(normalizeType('OutlinedButton'), 'button');
    assert.equal(normalizeType('TextButton'), 'button');
    assert.equal(normalizeType('IconButton'), 'button');
    assert.equal(normalizeType('FloatingActionButton'), 'button');
    assert.equal(normalizeType('SegmentedButton'), 'button');
    assert.equal(normalizeType('MaterialButton'), 'button');
  });
});

// ─── Material Text Input (4 assertions) ─────────────────────────────
describe('Material Text Input', () => {
  it('maps text input widgets', () => {
    assert.equal(normalizeType('TextField'), 'textfield');
    assert.equal(normalizeType('TextFormField'), 'textfield');
    assert.equal(normalizeType('SearchBar'), 'searchbar');
    assert.equal(normalizeType('SearchAnchor'), 'searchbar');
  });
});

// ─── Material Selection Controls (8 assertions) ─────────────────────
describe('Material Selection Controls', () => {
  it('maps selection widgets', () => {
    assert.equal(normalizeType('Switch'), 'switch');
    assert.equal(normalizeType('SwitchListTile'), 'switch');
    assert.equal(normalizeType('Checkbox'), 'checkbox');
    assert.equal(normalizeType('CheckboxListTile'), 'checkbox');
    assert.equal(normalizeType('Radio'), 'radio');
    assert.equal(normalizeType('RadioListTile'), 'radio');
    assert.equal(normalizeType('Slider'), 'slider');
    assert.equal(normalizeType('RangeSlider'), 'slider');
  });
});

// ─── Material Chips (5 assertions) ──────────────────────────────────
describe('Material Chips', () => {
  it('maps all chip variants', () => {
    assert.equal(normalizeType('Chip'), 'chip');
    assert.equal(normalizeType('ActionChip'), 'chip');
    assert.equal(normalizeType('ChoiceChip'), 'chip');
    assert.equal(normalizeType('FilterChip'), 'chip');
    assert.equal(normalizeType('InputChip'), 'chip');
  });
});

// ─── Material Dropdowns & Menus (5 assertions) ──────────────────────
describe('Material Dropdowns & Menus', () => {
  it('maps dropdown and menu widgets', () => {
    assert.equal(normalizeType('DropdownButton'), 'dropdown');
    assert.equal(normalizeType('DropdownButtonFormField'), 'dropdown');
    assert.equal(normalizeType('DropdownMenu'), 'dropdown');
    assert.equal(normalizeType('PopupMenuButton'), 'menu');
    assert.equal(normalizeType('MenuAnchor'), 'menu');
  });
});

// ─── Material Pickers (2 assertions) ────────────────────────────────
describe('Material Pickers', () => {
  it('maps picker dialogs', () => {
    assert.equal(normalizeType('DatePickerDialog'), 'picker');
    assert.equal(normalizeType('TimePickerDialog'), 'picker');
  });
});

// ─── Material Dialogs & Feedback (6 assertions) ─────────────────────
describe('Material Dialogs & Feedback', () => {
  it('maps dialog and feedback widgets', () => {
    assert.equal(normalizeType('AlertDialog'), 'dialog');
    assert.equal(normalizeType('SimpleDialog'), 'dialog');
    assert.equal(normalizeType('BottomSheet'), 'dialog');
    assert.equal(normalizeType('MaterialBanner'), 'banner');
    assert.equal(normalizeType('SnackBar'), 'snackbar');
    assert.equal(normalizeType('Tooltip'), 'tooltip');
  });
});

// ─── Material Navigation (10 assertions) ────────────────────────────
describe('Material Navigation', () => {
  it('maps navigation widgets', () => {
    assert.equal(normalizeType('AppBar'), 'appbar');
    assert.equal(normalizeType('SliverAppBar'), 'appbar');
    assert.equal(normalizeType('BottomAppBar'), 'appbar');
    assert.equal(normalizeType('BottomNavigationBar'), 'navbar');
    assert.equal(normalizeType('NavigationBar'), 'navbar');
    assert.equal(normalizeType('NavigationRail'), 'navbar');
    assert.equal(normalizeType('NavigationDrawer'), 'drawer');
    assert.equal(normalizeType('Drawer'), 'drawer');
    assert.equal(normalizeType('TabBar'), 'tabbar');
    assert.equal(normalizeType('Tab'), 'tab');
  });
});

// ─── Material Lists & Content (6 assertions) ────────────────────────
describe('Material Lists & Content', () => {
  it('maps list and content widgets', () => {
    assert.equal(normalizeType('ListTile'), 'tile');
    assert.equal(normalizeType('ExpansionTile'), 'tile');
    assert.equal(normalizeType('Card'), 'card');
    assert.equal(normalizeType('DataTable'), 'table');
    assert.equal(normalizeType('Stepper'), 'stepper');
    assert.equal(normalizeType('ExpansionPanelList'), 'panel');
  });
});

// ─── Touch & Gesture (6 assertions) ─────────────────────────────────
describe('Touch & Gesture', () => {
  it('maps gesture widgets', () => {
    assert.equal(normalizeType('GestureDetector'), 'gesture');
    assert.equal(normalizeType('InkWell'), 'gesture');
    assert.equal(normalizeType('InkResponse'), 'gesture');
    assert.equal(normalizeType('Dismissible'), 'gesture');
    assert.equal(normalizeType('Draggable'), 'gesture');
    assert.equal(normalizeType('LongPressDraggable'), 'gesture');
  });
});

// ─── Cupertino Widgets (19 assertions) ──────────────────────────────
describe('Cupertino Widgets', () => {
  it('maps cupertino button and input', () => {
    assert.equal(normalizeType('CupertinoButton'), 'button');
    assert.equal(normalizeType('CupertinoTextField'), 'textfield');
    assert.equal(normalizeType('CupertinoSearchTextField'), 'searchbar');
    assert.equal(normalizeType('CupertinoTextFormFieldRow'), 'textfield');
  });

  it('maps cupertino selection controls', () => {
    assert.equal(normalizeType('CupertinoSwitch'), 'switch');
    assert.equal(normalizeType('CupertinoSlider'), 'slider');
    assert.equal(normalizeType('CupertinoCheckbox'), 'checkbox');
    assert.equal(normalizeType('CupertinoRadio'), 'radio');
    assert.equal(normalizeType('CupertinoSegmentedControl'), 'segmented');
    assert.equal(normalizeType('CupertinoSlidingSegmentedControl'), 'segmented');
  });

  it('maps cupertino pickers and dialogs', () => {
    assert.equal(normalizeType('CupertinoPicker'), 'picker');
    assert.equal(normalizeType('CupertinoDatePicker'), 'picker');
    assert.equal(normalizeType('CupertinoTimerPicker'), 'picker');
    assert.equal(normalizeType('CupertinoAlertDialog'), 'dialog');
    assert.equal(normalizeType('CupertinoActionSheet'), 'dialog');
    assert.equal(normalizeType('CupertinoContextMenu'), 'menu');
  });

  it('maps cupertino navigation', () => {
    assert.equal(normalizeType('CupertinoNavigationBar'), 'appbar');
    assert.equal(normalizeType('CupertinoTabBar'), 'tabbar');
    assert.equal(normalizeType('CupertinoListTile'), 'tile');
  });
});

// ─── Scrolling & Layout (5 assertions) ──────────────────────────────
describe('Scrolling & Layout', () => {
  it('maps scrolling widgets', () => {
    assert.equal(normalizeType('ListView'), 'list');
    assert.equal(normalizeType('GridView'), 'grid');
    assert.equal(normalizeType('PageView'), 'pageview');
    assert.equal(normalizeType('ReorderableListView'), 'list');
    assert.equal(normalizeType('RefreshIndicator'), 'refresh');
  });
});

// ─── Display (non-interactive) (9 assertions) ───────────────────────
describe('Display widgets', () => {
  it('maps display widgets', () => {
    assert.equal(normalizeType('Text'), 'label');
    assert.equal(normalizeType('RichText'), 'label');
    assert.equal(normalizeType('Image'), 'image');
    assert.equal(normalizeType('Icon'), 'icon');
    assert.equal(normalizeType('Container'), 'container');
    assert.equal(normalizeType('Column'), 'column');
    assert.equal(normalizeType('Row'), 'row');
    assert.equal(normalizeType('Stack'), 'stack');
    assert.equal(normalizeType('Scaffold'), 'scaffold');
  });
});

// ─── Interactive Classification (14 assertions) ─────────────────────
describe('Interactive classification', () => {
  it('includes new interactive types in snapshot -i', () => {
    assert.equal(filterInteractive([mkEl('ActionChip')]).length, 1);
    assert.equal(filterInteractive([mkEl('SearchBar')]).length, 1);
    assert.equal(filterInteractive([mkEl('CupertinoSegmentedControl')]).length, 1);
    assert.equal(filterInteractive([mkEl('DatePickerDialog')]).length, 1);
    assert.equal(filterInteractive([mkEl('AlertDialog')]).length, 1);
    assert.equal(filterInteractive([mkEl('Stepper')]).length, 1);
    assert.equal(filterInteractive([mkEl('SnackBar')]).length, 1);
  });

  it('excludes non-interactive types from snapshot -i', () => {
    assert.equal(filterInteractive([mkEl('Drawer')]).length, 0);
    assert.equal(filterInteractive([mkEl('MaterialBanner')]).length, 0);
    assert.equal(filterInteractive([mkEl('Tooltip')]).length, 0);
    assert.equal(filterInteractive([mkEl('DataTable')]).length, 0);
    assert.equal(filterInteractive([mkEl('ListView')]).length, 0);
    assert.equal(filterInteractive([mkEl('GridView')]).length, 0);
    assert.equal(filterInteractive([mkEl('Text')]).length, 0);
  });
});

// ─── Snapshot Line Format (7 assertions) ────────────────────────────
describe('Snapshot line format for new types', () => {
  it('formats new display types correctly', () => {
    assert.ok(formatSnapshotLine(mkEl('ActionChip', 'Tag')).startsWith('@e1 [chip] "Tag"'));
    assert.ok(formatSnapshotLine(mkEl('SearchBar', 'Search')).startsWith('@e1 [searchbar] "Search"'));
    assert.ok(formatSnapshotLine(mkEl('CupertinoSegmentedControl')).startsWith('@e1 [segmented]'));
    assert.ok(formatSnapshotLine(mkEl('DatePickerDialog')).startsWith('@e1 [picker]'));
    assert.ok(formatSnapshotLine(mkEl('AlertDialog', 'Confirm?')).startsWith('@e1 [dialog] "Confirm?"'));
    assert.ok(formatSnapshotLine(mkEl('Stepper')).startsWith('@e1 [stepper]'));
    assert.ok(formatSnapshotLine(mkEl('SnackBar', 'Saved!')).startsWith('@e1 [snackbar] "Saved!"'));
  });
});

// ─── Fallback Behavior (2 assertions) ───────────────────────────────
describe('Fallback behavior', () => {
  it('unknown widget lowercases', () => {
    assert.equal(normalizeType('MyCustomWidget'), 'mycustomwidget');
    assert.equal(normalizeType('SuperSpecialButton'), 'superspecialbutton');
  });
});
