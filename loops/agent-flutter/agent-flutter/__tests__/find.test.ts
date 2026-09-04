/**
 * Unit tests for the find command's element matching logic.
 * Tests locator matching (key, text, type) and error cases.
 * Does NOT test live VM connection — that's covered by E2E tests.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import type { FlutterElement } from '../src/vm-client.ts';

// Import the internal matching functions by re-implementing them here
// (they're not exported, so we test the same logic)
import { normalizeType } from '../src/snapshot-fmt.ts';

function findAllMatches(elements: FlutterElement[], locator: string, value: string): FlutterElement[] {
  switch (locator) {
    case 'key':
      return elements.filter((el) => el.key === value);
    case 'text':
      return elements.filter((el) => el.text?.includes(value));
    case 'type':
      return elements.filter((el) => el.type === value || normalizeType(el.type) === value);
    default:
      throw new Error(`Unknown locator: ${locator}`);
  }
}

function findElement(elements: FlutterElement[], locator: string, value: string, index = 0): FlutterElement | null {
  const matches = findAllMatches(elements, locator, value);
  return matches[index] ?? null;
}

// Test fixtures
const ELEMENTS: FlutterElement[] = [
  { type: 'FilledButton', key: 'increment_btn', text: 'Increment', visible: true, bounds: { x: 0, y: 0, width: 100, height: 48 } },
  { type: 'TextField', key: 'name_field', visible: true, bounds: { x: 0, y: 50, width: 200, height: 56 } },
  { type: 'SwitchListTile', key: 'toggle_switch', text: 'Enable feature', visible: true, bounds: { x: 0, y: 120, width: 200, height: 56 } },
  { type: 'FilledButton', key: 'submit_btn', text: 'Submit', visible: true, bounds: { x: 0, y: 200, width: 200, height: 48 } },
  { type: 'OutlinedButton', key: 'reset_btn', text: 'Reset', visible: true, bounds: { x: 0, y: 260, width: 200, height: 48 } },
];

// ── find by key ──

test('find by key: returns matching element', () => {
  const el = findElement(ELEMENTS, 'key', 'submit_btn');
  assert.ok(el);
  assert.equal(el.key, 'submit_btn');
  assert.equal(el.text, 'Submit');
});

test('find by key: returns null for non-existent key', () => {
  const el = findElement(ELEMENTS, 'key', 'nonexistent');
  assert.equal(el, null);
});

test('find by key: exact match only', () => {
  const el = findElement(ELEMENTS, 'key', 'submit');
  assert.equal(el, null); // partial match should not work
});

// ── find by text ──

test('find by text: returns matching element', () => {
  const el = findElement(ELEMENTS, 'text', 'Submit');
  assert.ok(el);
  assert.equal(el.key, 'submit_btn');
});

test('find by text: partial match works', () => {
  const el = findElement(ELEMENTS, 'text', 'Incr');
  assert.ok(el);
  assert.equal(el.key, 'increment_btn');
});

test('find by text: returns null for non-existent text', () => {
  const el = findElement(ELEMENTS, 'text', 'Delete');
  assert.equal(el, null);
});

test('find by text: skips elements with no text', () => {
  const el = findElement(ELEMENTS, 'text', 'name_field');
  assert.equal(el, null); // name_field has no text property
});

// ── find by type ──

test('find by type: matches Flutter type name', () => {
  const el = findElement(ELEMENTS, 'type', 'TextField');
  assert.ok(el);
  assert.equal(el.key, 'name_field');
});

test('find by type: matches normalized type', () => {
  const el = findElement(ELEMENTS, 'type', 'button');
  assert.ok(el);
  assert.equal(el.key, 'increment_btn'); // first button
});

test('find by type: returns null for non-existent type', () => {
  const el = findElement(ELEMENTS, 'type', 'Slider');
  assert.equal(el, null);
});

// ── find with --index ──

test('find with index: returns Nth match', () => {
  // Multiple buttons exist
  const first = findElement(ELEMENTS, 'type', 'button', 0);
  const second = findElement(ELEMENTS, 'type', 'button', 1);
  const third = findElement(ELEMENTS, 'type', 'button', 2);
  assert.ok(first);
  assert.ok(second);
  assert.ok(third);
  assert.equal(first.key, 'increment_btn');
  assert.equal(second.key, 'submit_btn');
  assert.equal(third.key, 'reset_btn');
});

test('find with index: out of range returns null', () => {
  const el = findElement(ELEMENTS, 'type', 'button', 99);
  assert.equal(el, null);
});

// ── findAllMatches ──

test('findAllMatches: returns all matches', () => {
  const buttons = findAllMatches(ELEMENTS, 'type', 'button');
  assert.equal(buttons.length, 3); // increment, submit, reset
});

test('findAllMatches: empty array for no matches', () => {
  const results = findAllMatches(ELEMENTS, 'key', 'nonexistent');
  assert.equal(results.length, 0);
});

// ── unknown locator ──

test('find with unknown locator: throws error', () => {
  assert.throws(() => findElement(ELEMENTS, 'class', 'MyWidget'), /Unknown locator/);
});

// ── reconnect module: no auto-detect fallback ──

test('reconnect module: does not import auto-detect', async () => {
  const { readFileSync } = await import('node:fs');
  const { resolve } = await import('node:path');
  const reconnectSrc = readFileSync(resolve(import.meta.dirname, '../src/reconnect.ts'), 'utf-8');
  // After the fix, reconnect.ts should NOT have import statements referencing auto-detect
  assert.ok(!reconnectSrc.includes("from './auto-detect"), 'reconnect.ts should not import from auto-detect');
  assert.ok(!reconnectSrc.includes('detectVmServiceUri'), 'reconnect.ts should not call detectVmServiceUri');
});
