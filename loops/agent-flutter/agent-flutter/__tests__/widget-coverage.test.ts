import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeType, filterInteractive, formatSnapshotLine } from '../src/snapshot-fmt.ts';
import type { FlutterElement } from '../src/vm-client.ts';

function mkElement(type: string, text?: string, key?: string): FlutterElement {
  return { type, text, key, visible: true, bounds: { x: 0, y: 0, width: 100, height: 48 } };
}

// ─── Material Buttons ───────────────────────────────────────────────

describe('Material Buttons', () => {
  const buttons: [string, string][] = [
    ['ElevatedButton', 'button'],
    ['FilledButton', 'button'],
    ['OutlinedButton', 'button'],
    ['TextButton', 'button'],
    ['IconButton', 'button'],
    ['FloatingActionButton', 'button'],
    ['SegmentedButton', 'button'],
    ['MaterialButton', 'button'],
  ];

  for (const [widget, expected] of buttons) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Material Text Input ────────────────────────────────────────────

describe('Material Text Input', () => {
  const inputs: [string, string][] = [
    ['TextField', 'textfield'],
    ['TextFormField', 'textfield'],
    ['SearchBar', 'searchbar'],
    ['SearchAnchor', 'searchbar'],
  ];

  for (const [widget, expected] of inputs) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Material Selection Controls ────────────────────────────────────

describe('Material Selection Controls', () => {
  const controls: [string, string][] = [
    ['Switch', 'switch'],
    ['SwitchListTile', 'switch'],
    ['Checkbox', 'checkbox'],
    ['CheckboxListTile', 'checkbox'],
    ['Radio', 'radio'],
    ['RadioListTile', 'radio'],
    ['Slider', 'slider'],
    ['RangeSlider', 'slider'],
  ];

  for (const [widget, expected] of controls) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Material Chips ─────────────────────────────────────────────────

describe('Material Chips', () => {
  const chips: [string, string][] = [
    ['Chip', 'chip'],
    ['ActionChip', 'chip'],
    ['ChoiceChip', 'chip'],
    ['FilterChip', 'chip'],
    ['InputChip', 'chip'],
  ];

  for (const [widget, expected] of chips) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Material Dropdowns & Menus ─────────────────────────────────────

describe('Material Dropdowns & Menus', () => {
  const items: [string, string][] = [
    ['DropdownButton', 'dropdown'],
    ['DropdownButtonFormField', 'dropdown'],
    ['DropdownMenu', 'dropdown'],
    ['PopupMenuButton', 'menu'],
    ['MenuAnchor', 'menu'],
  ];

  for (const [widget, expected] of items) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Material Pickers ───────────────────────────────────────────────

describe('Material Pickers', () => {
  const pickers: [string, string][] = [
    ['DatePickerDialog', 'picker'],
    ['TimePickerDialog', 'picker'],
  ];

  for (const [widget, expected] of pickers) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Material Dialogs & Feedback ────────────────────────────────────

describe('Material Dialogs & Feedback', () => {
  const items: [string, string][] = [
    ['AlertDialog', 'dialog'],
    ['SimpleDialog', 'dialog'],
    ['BottomSheet', 'dialog'],
    ['MaterialBanner', 'banner'],
    ['SnackBar', 'snackbar'],
    ['Tooltip', 'tooltip'],
  ];

  for (const [widget, expected] of items) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Material Navigation ────────────────────────────────────────────

describe('Material Navigation', () => {
  const nav: [string, string][] = [
    ['AppBar', 'appbar'],
    ['SliverAppBar', 'appbar'],
    ['BottomAppBar', 'appbar'],
    ['BottomNavigationBar', 'navbar'],
    ['NavigationBar', 'navbar'],
    ['NavigationRail', 'navbar'],
    ['NavigationDrawer', 'drawer'],
    ['Drawer', 'drawer'],
    ['TabBar', 'tabbar'],
    ['Tab', 'tab'],
  ];

  for (const [widget, expected] of nav) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Material Lists & Content ───────────────────────────────────────

describe('Material Lists & Content', () => {
  const items: [string, string][] = [
    ['ListTile', 'tile'],
    ['ExpansionTile', 'tile'],
    ['Card', 'card'],
    ['DataTable', 'table'],
    ['Stepper', 'stepper'],
    ['ExpansionPanelList', 'panel'],
  ];

  for (const [widget, expected] of items) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Touch & Gesture ────────────────────────────────────────────────

describe('Touch & Gesture', () => {
  const gestures: [string, string][] = [
    ['GestureDetector', 'gesture'],
    ['InkWell', 'gesture'],
    ['InkResponse', 'gesture'],
    ['Dismissible', 'gesture'],
    ['Draggable', 'gesture'],
    ['LongPressDraggable', 'gesture'],
  ];

  for (const [widget, expected] of gestures) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Cupertino Widgets ──────────────────────────────────────────────

describe('Cupertino Widgets', () => {
  const cupertino: [string, string][] = [
    ['CupertinoButton', 'button'],
    ['CupertinoTextField', 'textfield'],
    ['CupertinoSearchTextField', 'searchbar'],
    ['CupertinoTextFormFieldRow', 'textfield'],
    ['CupertinoSwitch', 'switch'],
    ['CupertinoSlider', 'slider'],
    ['CupertinoCheckbox', 'checkbox'],
    ['CupertinoRadio', 'radio'],
    ['CupertinoSegmentedControl', 'segmented'],
    ['CupertinoSlidingSegmentedControl', 'segmented'],
    ['CupertinoPicker', 'picker'],
    ['CupertinoDatePicker', 'picker'],
    ['CupertinoTimerPicker', 'picker'],
    ['CupertinoAlertDialog', 'dialog'],
    ['CupertinoActionSheet', 'dialog'],
    ['CupertinoContextMenu', 'menu'],
    ['CupertinoNavigationBar', 'appbar'],
    ['CupertinoTabBar', 'tabbar'],
    ['CupertinoListTile', 'tile'],
  ];

  for (const [widget, expected] of cupertino) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Scrolling & Layout ─────────────────────────────────────────────

describe('Scrolling & Layout', () => {
  const scrolling: [string, string][] = [
    ['ListView', 'list'],
    ['GridView', 'grid'],
    ['PageView', 'pageview'],
    ['ReorderableListView', 'list'],
    ['RefreshIndicator', 'refresh'],
  ];

  for (const [widget, expected] of scrolling) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Display (non-interactive) ──────────────────────────────────────

describe('Display widgets', () => {
  const display: [string, string][] = [
    ['Text', 'label'],
    ['RichText', 'label'],
    ['Image', 'image'],
    ['Icon', 'icon'],
    ['Container', 'container'],
    ['Column', 'column'],
    ['Row', 'row'],
    ['Stack', 'stack'],
    ['Scaffold', 'scaffold'],
  ];

  for (const [widget, expected] of display) {
    it(`${widget} → ${expected}`, () => {
      assert.equal(normalizeType(widget), expected);
    });
  }
});

// ─── Interactive Classification ─────────────────────────────────────

describe('Interactive classification', () => {
  const interactiveWidgets = [
    'ElevatedButton', 'TextField', 'Switch', 'Checkbox', 'Radio', 'Slider',
    'DropdownButton', 'PopupMenuButton', 'GestureDetector', 'Tab',
    'Chip', 'ActionChip', 'ChoiceChip', 'FilterChip', 'InputChip',
    'SearchBar', 'CupertinoSegmentedControl', 'DatePickerDialog',
    'AlertDialog', 'Stepper', 'SnackBar',
    'CupertinoButton', 'CupertinoSwitch', 'CupertinoTextField',
  ];

  for (const widget of interactiveWidgets) {
    it(`${widget} is interactive`, () => {
      const result = filterInteractive([mkElement(widget)]);
      assert.equal(result.length, 1, `${widget} should be interactive`);
    });
  }

  const nonInteractiveWidgets = [
    'Text', 'RichText', 'Image', 'Icon', 'Container', 'Column', 'Row',
    'Stack', 'Scaffold', 'Card', 'Drawer', 'NavigationDrawer',
    'MaterialBanner', 'Tooltip', 'DataTable', 'ExpansionPanelList',
    'ListView', 'GridView', 'PageView', 'RefreshIndicator',
  ];

  for (const widget of nonInteractiveWidgets) {
    it(`${widget} is NOT interactive`, () => {
      const result = filterInteractive([mkElement(widget)]);
      assert.equal(result.length, 0, `${widget} should not be interactive`);
    });
  }
});

// ─── Fallback Behavior ──────────────────────────────────────────────

describe('Fallback behavior', () => {
  it('unknown widget lowercases', () => {
    assert.equal(normalizeType('MyCustomWidget'), 'mycustomwidget');
  });

  it('unknown CamelCase lowercases', () => {
    assert.equal(normalizeType('SuperSpecialButton'), 'superspecialbutton');
  });
});

// ─── Snapshot Line Format for New Types ─────────────────────────────

describe('Snapshot line format', () => {
  const newTypes: [string, string, string][] = [
    ['ActionChip', 'chip', 'Filter'],
    ['SearchBar', 'searchbar', 'Search...'],
    ['CupertinoSegmentedControl', 'segmented', 'Tab 1'],
    ['DatePickerDialog', 'picker', 'Select Date'],
    ['AlertDialog', 'dialog', 'Confirm?'],
    ['Stepper', 'stepper', 'Step 1'],
    ['SnackBar', 'snackbar', 'Saved!'],
    ['NavigationDrawer', 'drawer', ''],
    ['DataTable', 'table', ''],
    ['ListView', 'list', ''],
  ];

  for (const [widget, displayType, label] of newTypes) {
    it(`${widget} formats as [${displayType}]`, () => {
      const el = { ...mkElement(widget, label || undefined), ref: 'e1' };
      const line = formatSnapshotLine(el as any);
      assert.ok(line.startsWith(`@e1 [${displayType}]`), `Expected [${displayType}] in: ${line}`);
    });
  }
});

// ─── TYPE_MAP Completeness ──────────────────────────────────────────

describe('TYPE_MAP completeness', () => {
  const KNOWN_DISPLAY_TYPES = new Set([
    'button', 'textfield', 'searchbar', 'switch', 'checkbox', 'radio', 'slider',
    'chip', 'dropdown', 'menu', 'picker', 'dialog', 'banner', 'snackbar', 'tooltip',
    'appbar', 'navbar', 'drawer', 'tabbar', 'tab',
    'tile', 'card', 'table', 'stepper', 'panel',
    'gesture', 'label', 'image', 'icon',
    'container', 'column', 'row', 'stack', 'scaffold',
    'list', 'grid', 'pageview', 'refresh', 'segmented',
  ]);

  const ALL_EXPECTED_WIDGETS = [
    'ElevatedButton', 'FilledButton', 'OutlinedButton', 'TextButton', 'IconButton',
    'FloatingActionButton', 'SegmentedButton', 'MaterialButton',
    'TextField', 'TextFormField', 'SearchBar', 'SearchAnchor',
    'Switch', 'SwitchListTile', 'Checkbox', 'CheckboxListTile',
    'Radio', 'RadioListTile', 'Slider', 'RangeSlider',
    'Chip', 'ActionChip', 'ChoiceChip', 'FilterChip', 'InputChip',
    'DropdownButton', 'DropdownButtonFormField', 'DropdownMenu', 'PopupMenuButton', 'MenuAnchor',
    'DatePickerDialog', 'TimePickerDialog',
    'AlertDialog', 'SimpleDialog', 'BottomSheet', 'MaterialBanner', 'SnackBar', 'Tooltip',
    'AppBar', 'SliverAppBar', 'BottomAppBar', 'BottomNavigationBar',
    'NavigationBar', 'NavigationRail', 'NavigationDrawer', 'Drawer', 'TabBar', 'Tab',
    'ListTile', 'ExpansionTile', 'Card', 'DataTable', 'Stepper', 'ExpansionPanelList',
    'GestureDetector', 'InkWell', 'InkResponse', 'Dismissible', 'Draggable', 'LongPressDraggable',
    'CupertinoButton', 'CupertinoTextField', 'CupertinoSearchTextField', 'CupertinoTextFormFieldRow',
    'CupertinoSwitch', 'CupertinoSlider', 'CupertinoCheckbox', 'CupertinoRadio',
    'CupertinoSegmentedControl', 'CupertinoSlidingSegmentedControl',
    'CupertinoPicker', 'CupertinoDatePicker', 'CupertinoTimerPicker',
    'CupertinoAlertDialog', 'CupertinoActionSheet', 'CupertinoContextMenu',
    'CupertinoNavigationBar', 'CupertinoTabBar', 'CupertinoListTile',
    'ListView', 'GridView', 'PageView', 'ReorderableListView', 'RefreshIndicator',
    'Text', 'RichText', 'Image', 'Icon', 'Container', 'Column', 'Row', 'Stack', 'Scaffold',
  ];

  it('all expected widgets map to a known display type', () => {
    for (const widget of ALL_EXPECTED_WIDGETS) {
      const result = normalizeType(widget);
      assert.ok(
        KNOWN_DISPLAY_TYPES.has(result),
        `${widget} maps to unknown display type: ${result}`
      );
    }
  });

  it('all expected widgets are in the catalog', () => {
    assert.ok(ALL_EXPECTED_WIDGETS.length >= 85,
      `Only ${ALL_EXPECTED_WIDGETS.length} widgets in catalog, need >= 85`);
  });
});
